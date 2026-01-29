module Hke
  class FutureMessageSendJob
    include Sidekiq::Job
    include Hke::JobLoggingHelper

    def perform(future_message_id, community_id)
      # Check if community still exists
      community = Hke::Community.find_by(id: community_id)
      unless community
        log_error("Create Job", details: {
          text: "Skipping job - Community no longer exists",
          community_id: community_id,
          future_message_id: future_message_id
        })
        return # Don't retry for missing communities
      end

      ActsAsTenant.current_tenant = community

      # Check if future message still exists
      future_message = Hke::FutureMessage.find_by(id: future_message_id)
      unless future_message
        log_error("Create Job", details: {
          text: "Skipping job - FutureMessage no longer exists",
          future_message_id: future_message_id,
          community_id: community_id
        })
        ActsAsTenant.current_tenant = nil
        return # Don't retry for missing messages
      end

      begin
        log_event("Create Job", details: {
          text: "Creating send job for message: #{future_message_id}",
          community_id: community_id
        })

        # FutureMessage is delivery intent only; render message text at send time.
        rendered_text = future_message.rendered_full_message(reference_date: future_message.send_date || Time.zone.today)

        # Idempotency guard (pre-check)
        if Hke::SentMessage.exists?(token: future_message.token)
          log_event("Create Job", details: {
            text: "Skipping send (idempotent): #{future_message.id}",
            community_id: community_id
          })
          return
        end

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

        log_event("Create Job", details: {
          text: "Send job completed for message: #{future_message.id}",
          community_id: community_id
        })
      rescue ActiveRecord::RecordNotFound => e
        log_error("Create Job", details: {
          text: "Skipping job - Record not found: #{e.message}",
          future_message_id: future_message_id,
          community_id: community_id
        })
        # Don't retry for missing records
        return
      rescue => e
        log_error("Create Job", error: e, details: {
          community_id: community_id,
          future_message_id: future_message_id
        })
        raise e # Re-raise other errors for retry
      ensure
        ActsAsTenant.current_tenant = nil
      end
    end
  end
end
