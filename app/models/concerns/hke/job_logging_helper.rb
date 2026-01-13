# hke/lib/hke/job_logging_helper.rb
module Hke::JobLoggingHelper
  def log_event(event_type, entity: nil, message_token: nil, details: {})
    Hke::Logger.log(
      event_type: event_type,
      entity: entity,
      message_token: message_token || entity&.try(:token),
      details: details
    )
  end

  def log_error(event_type, entity: nil, message_token: nil, error: nil, details: {})
    Hke::Logger.log(
      event_type: event_type,
      entity: entity,
      message_token: message_token || entity&.try(:token),
      details: details,
      error: error
    )
  end
end
