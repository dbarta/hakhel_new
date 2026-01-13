module Hke
  class FutureMessageDailySchedulerJob
    include Sidekiq::Job
    include Hke::JobLoggingHelper

    def perform
      today = Date.current
      total_messages = Hke::FutureMessage.count
      todays_messages = Hke::FutureMessage.where(send_date: today)
      log_event("Daily Scheduler", details: {
        text: "Job started",
        total_messages: total_messages,
        scheduled_today: todays_messages.count
      })
      todays_messages.find_each do |future_message|
        ActsAsTenant.current_tenant = future_message.community if future_message.respond_to?(:community)
        Hke::FutureMessageSendJob.perform_async(future_message.id)
        log_event("Daily Scheduler", details: { text: "Enqueued send job for message: #{future_message.id}" })
      end
      ActsAsTenant.current_tenant = nil
    rescue => e
      log_error "Daily Scheduler", error: e
      raise e
    end
  end
end
