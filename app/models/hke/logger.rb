module Hke
  class Logger
    def self.log(event_type:, entity: nil, message_token: nil, details: {}, error: nil, event_time: Time.current)
      Hke::Log.create!(
        event_type:     event_type,
        entity_type:    entity&.class&.name,
        entity_id:      entity&.id,
        user_id:        Current.user&.id,
        community_id:   ActsAsTenant.current_tenant&.id,
        # ip_address:     Current.request&.ip,
        message_token:  message_token,
        event_time:     event_time,
        details:        details.presence || {},

        error_type:     error&.class&.name,
        error_message:  error&.message,
        error_trace:    error&.backtrace&.join("\n")
      )
    rescue => e
      Rails.logger.error("Failed to log #{event_type} for #{entity&.class&.name}##{entity&.id}: #{e.message}")
    end
  end
end
