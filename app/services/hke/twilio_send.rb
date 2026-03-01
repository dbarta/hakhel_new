# frozen_string_literal: true

# Hke::TwilioSend
# Module for sending messages through Twilio (SMS, WhatsApp) and SendGrid (Email).
# Included in FutureMessageSendJob to handle the actual message delivery.
#
# `send_message` treats the `methods:` array as a **priority list**:
# it tries the first method; on failure it logs and tries the next, etc.
# Returns `{ method: <Symbol>, sid: <String> }` for the method that succeeded.
module Hke
  module TwilioSend
    require "twilio-ruby"
    require "sendgrid-ruby"

    include SendGrid

    MODALITIES = %i[sms whatsapp email].freeze

    private

    # Main entry point.
    # +methods+:      ordered Array of symbols, e.g. [:whatsapp, :sms]
    # +phone+:        recipient phone (E.164)
    # +email+:        recipient email (may be nil if not sending email)
    # +message_text+: rendered message body
    #
    # Returns { method: :sms, sid: "SM..." }
    # Raises if every method in the list fails.
    def send_message(methods:, phone:, email:, message_text:)
      # DEBUG OVERRIDE – route all messages to a known number
      phone = "+972584579444"

      candidates = methods.select { |m| MODALITIES.include?(m) }
      raise ArgumentError, "No valid delivery methods in #{methods.inspect}" if candidates.empty?

      # Filter out methods where the required contact info is missing
      usable = candidates.select do |m|
        case m
        when :sms, :whatsapp then phone.present?
        when :email then email.present?
        else false
        end
      end

      if usable.empty?
        raise ArgumentError,
          "No usable delivery methods: #{candidates.inspect} (phone=#{phone.present? ? "yes" : "missing"}, email=#{email.present? ? "yes" : "missing"})"
      end

      client = build_twilio_client
      last_error = nil

      usable.each do |method|
        sid = case method
        when :sms then deliver_sms(client, phone, message_text)
        when :whatsapp then deliver_whatsapp(client, phone, message_text)
        when :email then deliver_email(email, message_text)
        end

        Rails.logger.info "[TwilioSend] Delivered via #{method}, SID: #{sid}"
        return {method: method, sid: sid}
      rescue => e
        last_error = e
        Rails.logger.warn "[TwilioSend] #{method} failed: #{e.message}"
      end

      raise last_error
    end

    # -------------------------
    # Transport implementations
    # -------------------------

    def build_twilio_client
      Twilio::REST::Client.new(
        ENV["TWILIO_ACCOUNT_SID"] || Rails.application.credentials.dig(:twilio, :account_sid),
        ENV["TWILIO_AUTH_TOKEN"] || Rails.application.credentials.dig(:twilio, :auth_token)
      )
    end

    def deliver_sms(client, phone, text)
      from = current_community_phone ||
        ENV["TWILIO_PHONE_NUMBER"] ||
        Rails.application.credentials.dig(:twilio, :phone_number)

      params = {from: from, to: phone, body: text}
      cb = webhook_url(:sms)
      params[:status_callback] = cb if cb
      msg = client.messages.create(**params)
      msg.sid
    end

    def deliver_whatsapp(client, phone, text)
      params = {
        from: "whatsapp:+14155238886",
        to: "whatsapp:#{phone}",
        body: text
      }
      cb = webhook_url(:whatsapp)
      params[:status_callback] = cb if cb
      msg = client.messages.create(**params)
      msg.sid
    end

    def deliver_email(to_email, text)
      from_addr = current_community_email ||
        ENV["SENDGRID_FROM_EMAIL"] ||
        "no-reply@hakhel.me"

      from = SendGrid::Email.new(email: from_addr)
      to = SendGrid::Email.new(email: to_email)
      subject = "הודעה מהקהל"
      content = SendGrid::Content.new(type: "text/plain", value: text)

      mail = SendGrid::Mail.new(from, subject, to, content)
      sg = SendGrid::API.new(
        api_key: ENV["SENDGRID_API_KEY"] ||
                 Rails.application.credentials.dig(:sendgrid, :api_key)
      )
      response = sg.client.mail._("send").post(request_body: mail.to_json)

      unless response.status_code.to_i.between?(200, 299)
        raise "SendGrid failed with status #{response.status_code}"
      end

      "email-#{SecureRandom.hex(6)}"
    end

    # -------------------------
    # Helpers
    # -------------------------

    def webhook_url(modality)
      host = ENV["WEBHOOK_HOST"] ||
        Rails.application.routes.default_url_options[:host]
      return nil if host.blank? || host.include?("localhost")
      "#{host}/hke/api/v1/twilio/sms/status?modality=#{modality}"
    end

    def current_community_phone
      return nil unless ActsAsTenant.current_tenant.is_a?(Hke::Community)
      ActsAsTenant.current_tenant.phone_number
    end

    def current_community_email
      return nil unless ActsAsTenant.current_tenant.is_a?(Hke::Community)
      ActsAsTenant.current_tenant.email_address
    end
  end
end
