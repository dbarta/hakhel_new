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

        Hke::MessageProcessor.new(future_message).call

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
