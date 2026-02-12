module Hke
  class FutureMessageSendJob
    include Sidekiq::Job
    include Hke::JobLoggingHelper

    def perform(future_message_id, community_id)
      community = find_community(community_id, future_message_id)
      return unless community

      with_tenant(community) do
        future_message = find_future_message(future_message_id, community_id)
        return unless future_message

        log_start(future_message_id, community_id)

        unless approved?(future_message)
          log_event("Create Job", details: {
            text: "Skipping send - not approved",
            community_id: community_id,
            future_message_id: future_message.id
          })
          return
        end

        return if before_send_window?(future_message, community_id)

        return if already_sent?(future_message, community_id)

        rendered_text = render_text(future_message)

        create_sent_and_delete_future!(future_message, rendered_text, community_id)

        future_message.messageable.process_future_messages

        log_done(future_message.id, community_id)
      end
    rescue ActiveRecord::RecordNotFound => e
      log_missing_record(e, future_message_id, community_id)
    rescue => e
      log_error("Create Job", error: e, details: {
        community_id: community_id,
        future_message_id: future_message_id
      })
      raise
    end

    private

    # -------------------------
    # Lookup & tenancy
    # -------------------------

    def find_community(community_id, future_message_id)
      community = Hke::Community.find_by(id: community_id)
      return community if community

      log_error("Create Job", details: {
        text: "Skipping job - Community no longer exists",
        community_id: community_id,
        future_message_id: future_message_id
      })
      nil
    end

    def with_tenant(community)
      ActsAsTenant.current_tenant = community
      yield
    ensure
      ActsAsTenant.current_tenant = nil
    end

    def find_future_message(future_message_id, community_id)
      future_message = Hke::FutureMessage.find_by(id: future_message_id)
      return future_message if future_message

      log_error("Create Job", details: {
        text: "Skipping job - FutureMessage no longer exists",
        future_message_id: future_message_id,
        community_id: community_id
      })
      nil
    end

    # -------------------------
    # Logging helpers
    # -------------------------

    def log_start(future_message_id, community_id)
      log_event("Create Job", details: {
        text: "Creating send job for message: #{future_message_id}",
        community_id: community_id
      })
    end

    def log_done(future_message_id, community_id)
      log_event("Create Job", details: {
        text: "Send job completed for message: #{future_message_id}",
        community_id: community_id
      })
    end

    def log_missing_record(error, future_message_id, community_id)
      log_error("Create Job", details: {
        text: "Skipping job - Record not found: #{error.message}",
        future_message_id: future_message_id,
        community_id: community_id
      })
    end

    # -------------------------
    # Core logic
    # -------------------------
    #
    def approved?(future_message)
      return future_message.approved? if future_message.respond_to?(:approved?)
      future_message.approval_status.to_s == "approved" || future_message.approval_status.to_i == 1
    end

    def before_send_window?(future_message, community_id)
      relation = future_message.messageable
      resolved = Hke::PreferenceResolver.resolve(preferring: relation)
      hm = resolved.send_window_start_wall_clock_hm
      return false if hm.nil?

      tz = ActiveSupport::TimeZone["Asia/Jerusalem"]
      now = tz.now
      start_time = tz.local(now.year, now.month, now.day, hm[0], hm[1], 0)

      return false if now >= start_time

      delay = (start_time - now).to_i
      self.class.perform_in(delay, future_message.id, community_id)

      log_event("Create Job", details: {
        text: "Re-enqueueing before send window",
        community_id: community_id,
        future_message_id: future_message.id,
        delay: delay
      })

      true
    end

    def already_sent?(future_message, community_id)
      return false unless Hke::SentMessage.exists?(token: future_message.token)

      log_event("Create Job", details: {
        text: "Skipping send (idempotent): #{future_message.id}",
        community_id: community_id
      })
      true
    end

    def render_text(future_message)
      # FutureMessage is delivery intent only.
      # Render message text dynamically from the Relation.
      relation = future_message.messageable

      Hke::MessageRenderer.render(
        relation: relation,
        delivery_method: future_message.delivery_method.to_sym,
        reference_date: future_message.send_date || Time.zone.today
      )
    end

    def create_sent_and_delete_future!(future_message, rendered_text, community_id)
      Hke::SentMessage.transaction do
        # Idempotency guard (in-transaction)
        if Hke::SentMessage.exists?(token: future_message.token)
          log_event("Create Job", details: {
            text: "Skipping send inside transaction (idempotent): #{future_message.id}",
            community_id: community_id
          })
          return
        end

        Hke::SentMessage.create!(
          messageable_type: future_message.messageable_type,
          messageable_id: future_message.messageable_id,
          send_date: future_message.send_date,
          full_message: rendered_text,
          message_type: future_message.message_type,
          delivery_method: future_message.delivery_method,
          email: future_message.email,
          phone: future_message.phone,
          token: future_message.token,
          community_id: future_message.community_id
        )

        # SentMessage is immutable audit log; delete intent only after commit.
        future_message.destroy!
      end
    end
  end
end
