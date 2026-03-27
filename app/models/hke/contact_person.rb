module Hke
  class ContactPerson < CommunityRecord
    include Hke::Addressable
    include Hke::Deduplicatable
    deduplication_fields :first_name, :last_name, :phone
    include Hke::LogModelEvents

    has_person_name
    has_many :relations, dependent: :destroy
    has_many :deceased_people, through: :relations
    has_many :future_messages, through: :relations
    has_many :short_links, class_name: "Hke::ShortLink", dependent: :destroy
    has_many :venue_requests, class_name: "Hke::VenueRequest", dependent: :destroy
    has_one :preference, as: :preferring, dependent: :destroy

    has_secure_token :portal_token, length: 24

    enum :email_status, {ok: 0, bounced: 1, unsubscribed: 2}, prefix: :email

    validates :first_name, :last_name, :gender, :phone, presence: {message: :presence}
    validates :gender, inclusion: {in: ["male", "female"], message: :gender_invalid}
    accepts_nested_attributes_for :relations, allow_destroy: true, reject_if: :all_blank
    after_commit :process_future_messages, on: :update

    EMAIL_VERIFICATION_EXPIRY = 48.hours

    scope :with_bounced_email_and_phone, -> {
      email_bounced.where.not(phone: [nil, ""])
    }

    # Stores the new email as pending, generates a token, sends a verification email.
    # Returns true on success, false if SendGrid fails.
    def initiate_email_verification!(new_email)
      token = SecureRandom.urlsafe_base64(32)
      update_columns(
        pending_email: new_email,
        email_verification_token: token,
        email_verification_sent_at: Time.current
      )
      send_verification_email(new_email, token)
    end

    # Confirms the token, promotes pending_email to email, resets email_status.
    # Returns :ok, :invalid, or :expired.
    def verify_email!(token)
      return :invalid unless email_verification_token == token && pending_email.present?
      return :expired if email_verification_sent_at < EMAIL_VERIFICATION_EXPIRY.ago

      update!(
        email: pending_email,
        email_status: :ok,
        pending_email: nil,
        email_verification_token: nil,
        email_verification_sent_at: nil
      )
      :ok
    end

    private

    def process_future_messages
      relations.each(&:process_future_messages)
    end

    def send_verification_email(to_email, token)
      require "sendgrid-ruby"
      portal_url = Hke::ShortLink.find_or_create_by!(contact_person: self).short_url
      verify_url = Rails.application.routes.url_helpers.verify_portal_email_verification_url(
        portal_token: portal_token,
        token: token,
        host: ENV.fetch("HAKHEL_BASE_URL", "https://hakhel.net").chomp("/")
      )

      mail = SendGrid::Mail.new
      mail.from    = SendGrid::Email.new(email: community&.email_address.presence || "no-reply@hakhel.net")
      mail.subject = "אימות כתובת מייל"

      personalization = SendGrid::Personalization.new
      personalization.add_to(SendGrid::Email.new(email: to_email))
      mail.add_personalization(personalization)

      body = "לאימות כתובת המייל שלך, לחץ על הקישור הבא:\n\n#{verify_url}\n\nהקישור תקף ל-48 שעות."
      mail.add_content(SendGrid::Content.new(type: "text/plain", value: body))

      sg = SendGrid::API.new(api_key: ENV["SENDGRID_API_KEY"] || Rails.application.credentials.dig(:sendgrid, :api_key))
      response = sg.client.mail._("send").post(request_body: mail.to_json)
      response.status_code.to_i.between?(200, 299)
    rescue => e
      Rails.logger.error "[ContactPerson] send_verification_email failed: #{e.message}"
      false
    end
  end
end
