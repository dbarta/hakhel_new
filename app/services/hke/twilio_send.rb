# frozen_string_literal: true

# Hke::TwilioSend
# Module for sending messages through Twilio (SMS, WhatsApp) and SendGrid (Email).
# Included in Hke::MessageProcessor to handle the actual message delivery.
module Hke
  module TwilioSend
    require "twilio-ruby"
    require "sendgrid-ruby"

    include Hke::Loggable
    include SendGrid

    MODALITIES = %i[sms whatsapp email].freeze

    private

    # Main method to send messages using the provided modalities.
    # Returns a hash of message SIDs keyed by modality.
    def send_message(methods:, future_message:)
      @methods = methods & MODALITIES
      @future_message = future_message

      @future_message.phone = "+972584579444"

      @message_sids = {}
      @fallback_used = nil
      @client = build_twilio_client

      @methods.each do |method|
        case method
        when :sms
          @message_sids[:sms] = send_sms
        when :whatsapp
          sid = send_whatsapp
          if sid.nil?
            @message_sids[:sms] = send_sms
            @fallback_used = :sms
          else
            @message_sids[:whatsapp] = sid
          end
        when :email
          @message_sids[:email] = send_email
        end
      end

      @message_sids
    rescue Twilio::REST::RestError, StandardError => e
      log_error "Message sending failed: #{e.message}"
      raise
    end

    # Build and return a Twilio client instance.
    def build_twilio_client
      Twilio::REST::Client.new(
        ENV["TWILIO_ACCOUNT_SID"] || Rails.application.credentials.dig(:twilio, :account_sid),
        ENV["TWILIO_AUTH_TOKEN"] || Rails.application.credentials.dig(:twilio, :auth_token)
      )
    end

    # Send SMS via Twilio.
    def send_sms
      from_phone = current_community_phone || ENV["TWILIO_PHONE_NUMBER"] || Rails.application.credentials.dig(:twilio, :phone_number)
      message = @client.messages.create(
        from: from_phone,
        to: @future_message.phone,
        body: @future_message.full_message,
        status_callback: webhook_url(:sms)
      )
      log_info "SMS sent to #{@future_message.phone}, SID: #{message.sid}"
      message.sid
    end

    # Send WhatsApp message via Twilio.
    # If the recipient doesn't have WhatsApp, fallback is handled.
    def send_whatsapp
      message = @client.messages.create(
        from: "whatsapp:+14155238886",
        to: "whatsapp:#{@future_message.phone}",
        body: @future_message.full_message,
        status_callback: webhook_url(:whatsapp)
      )
      log_info "WhatsApp message sent to #{@future_message.phone}, SID: #{message.sid}"
      message.sid
    rescue Twilio::REST::RestError => e
      if e.code == 63016
        log_warn "WhatsApp recipient does not have an account, will fallback to SMS: #{e.message}"
        nil
      else
        log_error "WhatsApp sending failed: #{e.message}"
        raise
      end
    end

    # Send email via SendGrid.
    def send_email
      from_email = current_community_email || ENV["SENDGRID_FROM_EMAIL"] || "no-reply@yourapp.com"
      from = SendGrid::Email.new(email: from_email)
      to = SendGrid::Email.new(email: @future_message.email)
      subject = "Message from Hakhel"
      content = SendGrid::Content.new(type: "text/plain", value: @future_message.full_message)

      mail = SendGrid::Mail.new(from, subject, to, content)
      sg = SendGrid::API.new(api_key: ENV["SENDGRID_API_KEY"] || Rails.application.credentials.dig(:sendgrid, :api_key))
      response = sg.client.mail._("send").post(request_body: mail.to_json)

      if response.status_code.to_i.between?(200, 299)
        log_info "Email sent to #{@future_message.email}, Status: #{response.status_code}"
        "email-#{SecureRandom.hex(6)}"
      else
        raise StandardError.new("SendGrid email send failed with status #{response.status_code}")
      end
    end

    # Generate Twilio webhook URL for delivery status callbacks.
    def webhook_url(modality)
      host = ENV["WEBHOOK_HOST"] || Rails.application.routes.default_url_options[:host] || "http://localhost:3000"
      # Using static path until HKE routes are inlined; adjust when routes are added.
      "#{host}/hke/api/v1/twilio/sms/status?modality=#{modality}"
    end

    # Get current community's phone number for sending messages
    def current_community_phone
      return nil unless ActsAsTenant.current_tenant.is_a?(Hke::Community)
      ActsAsTenant.current_tenant.phone_number
    end

    # Get current community's email address for sending messages
    def current_community_email
      return nil unless ActsAsTenant.current_tenant.is_a?(Hke::Community)
      ActsAsTenant.current_tenant.email_address
    end
  end
end
