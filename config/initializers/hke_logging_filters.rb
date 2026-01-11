# Simple logging filters for development environment
if Rails.env.development?
  Rails.application.configure do
    config.after_initialize do
      # Disable ActionCable logging completely
      if defined?(ActionCable)
        ActionCable.server.config.logger = Logger.new(nil)
        ActionCable.server.config.disable_request_forgery_protection = true
      end
    end
  end
end
