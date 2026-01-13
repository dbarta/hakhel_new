module Hke
  class FutureMessageCommunityDailySchedulerJob
    include Sidekiq::Job
    include Hke::JobLoggingHelper

    def perform(community_id)
      community = Hke::Community.find_by(id: community_id)
      unless community
        log_error("Daily Scheduler", details: { text: "Community #{community_id} not found" })
        return
      end
      ActsAsTenant.current_tenant = community
      today = Date.current
      total_messages = Hke::FutureMessage.where(community_id: community.id).count
      todays_messages = Hke::FutureMessage.where(community_id: community.id, send_date: today)
      log_event("Daily Scheduler", details: {
        text: "Job started",
        community_id: community.id,
        total_messages: total_messages,
        scheduled_today: todays_messages.count
      })
      todays_messages.find_each do |future_message|
        Hke::FutureMessageSendJob.perform_async(future_message.id, community.id)
        log_event("Daily Scheduler", details: { text: "Enqueued send job for message: #{future_message.id}", community_id: community.id })
      end
      ActsAsTenant.current_tenant = nil
    rescue => e
      log_error "Daily Scheduler", error: e, details: { community_id: community_id }
      ActsAsTenant.current_tenant = nil
      raise e
    end
  end
end
