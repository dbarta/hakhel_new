module Hke
  module LogModelEvents
    extend ActiveSupport::Concern

    included do
      after_create  { log_model_event("create", self.attributes) }
      after_update do
        changes = saved_changes.except(:updated_at)
        log_model_event("update", changes) unless changes.empty?
      end
      after_destroy { log_model_event("destroy", self.attributes) }
    end

    private

    def log_model_event(event_type, data)
      Hke::Logger.log(
        event_type: event_type,
        entity: self,
        details: data
      )
    end
  end
end
