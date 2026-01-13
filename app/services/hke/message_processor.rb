# frozen_string_literal: true

# Hke::MessageProcessor
# Orchestrates sending a future message, handling fallback logic,
# and persisting the result in Hke::SentMessage.
module Hke
  class MessageProcessor
    include Hke::TwilioSend
    include Hke::Loggable
    include Hke::JobLoggingHelper

    def initialize(future_message)
      @future_message = future_message
    end

    def call
      log_event "Process Message", details:
        {text: "Start send process for message: #{@future_message.id} delivery_methods: #{delivery_methods}" }

      @future_message.full_message = @future_message.rendered_full_message(reference_date: Time.zone.today)

      message_sids = send_message(
        methods: delivery_methods,
        future_message: @future_message
      )

      log_event "Process Message", details:
        {text: "Message: #{@future_message.id} sent. sid: #{message_sids.values.first} delivery_method: #{final_delivery_method}" }

      Hke::SentMessage.create!(
        copy_attributes.merge(
          twilio_message_sid: message_sids.values.first,
          delivery_method: Hke::FutureMessage.delivery_methods[final_delivery_method]
        )
      )

      @future_message.destroy!
    rescue => e
      log_error "Process Message", entity: @future_message, error: e
      raise
    end

    private

    def delivery_methods
      [@future_message.messageable.delivery_method_name]
    end

    def final_delivery_method
      @fallback_used || @future_message.messageable.delivery_method_name
    end

    def copy_attributes
      @future_message.attributes.slice(
        "messageable_type", "messageable_id", "send_date", "full_message",
        "message_type", "metadata", "delivery_method", "email", "phone", "token",
        "deceased_first_name", "deceased_last_name", "contact_first_name", "contact_last_name",
        "hebrew_year_of_death", "hebrew_month_of_death", "hebrew_day_of_death",
        "relation_of_deceased_to_contact", "date_of_death", "community_id"
      )
    end
  end
end
