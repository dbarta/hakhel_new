module Hke
  # Runs daily (before the send job) to handle FutureMessages whose send_date has passed.
  #
  # For each past-due message:
  #   A) Yahrzeit has already passed this year:
  #      → Archive to NotSentMessage (reason: missed_yahrzeit)
  #      → Delete the FutureMessage
  #      → Call relation.create_future_messages to schedule next year
  #
  #   B) Yahrzeit is still upcoming:
  #      → Recalculate the ideal send_date from preferences
  #      → If ideal date is still in the future: reschedule (update send_date)
  #      → If ideal date has also passed (we missed the window):
  #          attempt_to_resend_if_no_sent_on_time = true  → reschedule for today
  #          attempt_to_resend_if_no_sent_on_time = false → archive as missed_send_window
  class FutureMessagePastDueRecoveryJob
    include Sidekiq::Job
    include Hke::JobLoggingHelper

    def perform(community_id)
      community = Hke::Community.find_by(id: community_id)
      unless community
        log_error("PastDueRecovery", details: { text: "Community #{community_id} not found" })
        return
      end

      ActsAsTenant.current_tenant = community
      today = Date.current

      past_due = Hke::FutureMessage
        .where(community_id: community.id)
        .where("send_date < ?", today)

      log_event("PastDueRecovery", details: {
        community_id: community_id,
        past_due_count: past_due.count
      })

      past_due.find_each do |future_message|
        handle_past_due(future_message, today, community_id)
      end
    rescue => e
      log_error("PastDueRecovery", error: e, details: { community_id: community_id })
      raise e
    ensure
      ActsAsTenant.current_tenant = nil
    end

    private

    def handle_past_due(future_message, today, community_id)
      relation = future_message.messageable
      unless relation.is_a?(Hke::Relation)
        log_event("PastDueRecovery", details: {
          text: "Skipping non-Relation messageable for FutureMessage #{future_message.id}"
        })
        return
      end

      dp = relation.deceased_person

      # Use the message's original send_date as the reference so we find the yahrzeit
      # that this message was targeting — not next year's if that one has since passed.
      targeted_yahrzeit = Hke::Heb.yahrzeit_date(
        dp.name, dp.hebrew_month_of_death, dp.hebrew_day_of_death,
        reference_date: future_message.send_date
      )

      if targeted_yahrzeit < today
        handle_yahrzeit_passed(future_message, relation, targeted_yahrzeit, community_id)
      else
        handle_yahrzeit_upcoming(future_message, relation, targeted_yahrzeit, today, community_id)
      end
    rescue => e
      log_error("PastDueRecovery", error: e, details: {
        future_message_id: future_message.id,
        community_id: community_id
      })
    end

    # Case A: the yahrzeit for this year has already passed — archive and reschedule for next year
    def handle_yahrzeit_passed(future_message, relation, yahrzeit_date, community_id)
      log_event("PastDueRecovery", details: {
        text: "Yahrzeit passed — archiving and rescheduling next year",
        future_message_id: future_message.id,
        yahrzeit_date: yahrzeit_date
      })

      Hke::NotSentMessage.transaction do
        archive!(future_message, :missed_yahrzeit)
        future_message.destroy!
      end

      # Schedule next year's message
      relation.create_future_messages
    end

    # Case B: yahrzeit is upcoming — recalculate ideal send_date
    def handle_yahrzeit_upcoming(future_message, relation, yahrzeit_date, today, community_id)
      resolved = Hke::PreferenceResolver.resolve(preferring: relation)
      offsets  = Array(resolved.how_many_days_before_yahrzeit_to_send_message).compact.map(&:to_i).sort
      offsets  = [7] if offsets.empty?

      # Pick the latest offset whose date is still before the yahrzeit
      ideal_date = offsets.map { |d| yahrzeit_date - d.days }.select { |d| d < yahrzeit_date }.max

      if ideal_date && ideal_date >= today
        # Ideal window is still in the future — just reschedule
        log_event("PastDueRecovery", details: {
          text: "Rescheduling to ideal send_date",
          future_message_id: future_message.id,
          new_send_date: ideal_date
        })
        future_message.update_columns(send_date: ideal_date)

      elsif resolved.attempt_to_resend_if_no_sent_on_time
        # Ideal window passed but retry is enabled — send today
        log_event("PastDueRecovery", details: {
          text: "Ideal window passed, retry enabled — rescheduling for today",
          future_message_id: future_message.id,
          yahrzeit_date: yahrzeit_date
        })
        future_message.update_columns(send_date: today)

      else
        # Ideal window passed and retry is disabled — archive as missed_send_window
        log_event("PastDueRecovery", details: {
          text: "Ideal window passed, retry disabled — archiving",
          future_message_id: future_message.id,
          yahrzeit_date: yahrzeit_date
        })
        Hke::NotSentMessage.transaction do
          archive!(future_message, :missed_send_window)
          future_message.destroy!
        end
        # Still create next year's message
        relation.create_future_messages
      end
    end

    def archive!(future_message, reason)
      rendered_text = begin
        Hke::MessageRenderer.render(
          relation: future_message.messageable,
          delivery_method: future_message.delivery_method.to_sym,
          reference_date: future_message.send_date || Date.today
        ).to_s
      rescue
        nil
      end

      Hke::NotSentMessage.create!(
        messageable_type: future_message.messageable_type,
        messageable_id:   future_message.messageable_id,
        send_date:        future_message.send_date,
        full_message:     rendered_text,
        message_type:     future_message.message_type,
        delivery_method:  future_message.delivery_method,
        email:            future_message.email,
        phone:            future_message.phone,
        token:            future_message.token,
        community_id:     future_message.community_id,
        reason:           reason
      )
    end
  end
end
