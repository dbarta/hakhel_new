require 'twilio-ruby'

module Hke
  class TwilioSmsSender
    def self.send_sms(to:, message:)
      client = Twilio::REST::Client.new(
        ENV['TWILIO_ACCOUNT_SID'] || Rails.application.credentials.dig(:twilio, :account_sid),
        ENV['TWILIO_AUTH_TOKEN'] || Rails.application.credentials.dig(:twilio, :auth_token)
      )

      client.messages.create(
        from: ENV['TWILIO_PHONE_NUMBER'] || Rails.application.credentials.dig(:twilio, :phone_number),
        to: to,
        body: message
      )
    end
  end
end


