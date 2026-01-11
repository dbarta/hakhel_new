module Hke
  class SentMessage < CommunityRecord
    include Hke::Loggable
    include Hke::LogModelEvents

    belongs_to :messageable, polymorphic: true
    has_secure_token :token

    scope :filter_by_name, ->(name) {
      return all if name.blank?

      pattern = name.chars.join('%') # Convert "דוד" → "ד%ו%ד"

      joins("INNER JOIN hke_relations ON hke_relations.id = hke_future_messages.messageable_id")
      .joins("INNER JOIN hke_deceased_people ON hke_deceased_people.id = hke_relations.deceased_person_id")
      .joins("INNER JOIN hke_contact_people ON hke_contact_people.id = hke_relations.contact_person_id")
      .where(
        "hke_deceased_people.first_name ILIKE :pattern OR
        hke_deceased_people.last_name ILIKE :pattern OR
        hke_contact_people.first_name ILIKE :pattern OR
        hke_contact_people.last_name ILIKE :pattern",
        pattern: "%#{pattern}%"
      )
    }

    scope :filter_by_date_range, ->(start_date, end_date) {
      return all if start_date.blank? && end_date.blank?

      where("send_date BETWEEN ? AND ?", start_date || 100.years.ago, end_date || 100.years.from_now)
    }

    # Enum for delivery method
    enum :delivery_method, {no_delivery: 0,
                            email: 1,
                            sms: 2,
                            whatsapp: 4}

    validates :send_date, presence: true
    validates :delivery_method, presence: true
    validates :full_message, presence: true
    validates :email, presence: true, if: -> { delivery_method == "email" }
    validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}, if: -> { email.present? }
    validates :phone, presence: true, if: -> { %w[sms whatsapp phone].include?(delivery_method) }

    # Placeholder for message_type validation; clarify what message_type represents
    # validates :message_type, presence: true, inclusion: { in: [/* expected values */] }

  end
end
