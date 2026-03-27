module Hke
  class BounceNotificationSmsJob
    include Sidekiq::Job

    def perform(contact_person_id, community_id)
      community = Hke::Community.find(community_id)

      ActsAsTenant.with_tenant(community) do
        contact = Hke::ContactPerson.find(contact_person_id)
        return unless contact.email_bounced? && contact.phone.present?

        portal_url = Hke::ShortLink.find_or_create_by!(contact_person: contact).short_url
        body = I18n.t("hke.bounce_notifications.sms_body",
          name: contact.first_name,
          email: contact.email.to_s,
          url: portal_url)

        client = Twilio::REST::Client.new(
          ENV["TWILIO_ACCOUNT_SID"] || Rails.application.credentials.dig(:twilio, :account_sid),
          ENV["TWILIO_AUTH_TOKEN"]  || Rails.application.credentials.dig(:twilio, :auth_token)
        )
        from = community.phone_number.presence ||
               ENV["TWILIO_PHONE_NUMBER"] ||
               Rails.application.credentials.dig(:twilio, :phone_number)

        client.messages.create(from: from, to: contact.phone, body: body)
        contact.update_columns(bounce_sms_sent_at: Time.current)
      end
    rescue => e
      Rails.logger.error "[BounceNotificationSmsJob] Failed for contact #{contact_person_id}: #{e.message}"
      raise
    end
  end
end
