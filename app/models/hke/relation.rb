module Hke
  class Relation < CommunityRecord
    include Hke::Deduplicatable
    include Hke::LogModelEvents
    include Hke::MessageGenerator
    deduplication_fields :deceased_person_id, :contact_person_id

    belongs_to :deceased_person
    belongs_to :contact_person
    has_many :future_messages, as: :messageable, dependent: :destroy
    has_many :relations_selections
    has_many :selections, through: :relations_selections
    has_one :preference, as: :preferring, dependent: :destroy
    has_secure_token length: 24
    accepts_nested_attributes_for :contact_person, reject_if: :all_blank
    accepts_nested_attributes_for :deceased_person, reject_if: :all_blank
    after_commit :process_future_messages

    # Setter method for contact_person nested attributes
    def contact_person_attributes=(attributes)
      if attributes["phone"].present?
        self.contact_person = ContactPerson.find_or_initialize_by(phone: attributes["phone"])
        contact_person.assign_attributes(attributes)
      end
    end

    # Setter method for deceased_person nested attributes
    def deceased_person_attributes=(attributes)
      if attributes["first_name"].present? && attributes["last_name"].present?
        self.deceased_person = DeceasedPerson.find_or_initialize_by(
          first_name: attributes["first_name"],
          last_name: attributes["last_name"]
        )
        deceased_person.assign_attributes(attributes)
      end
    end

    def process_future_messages
      return if destroyed? || !persisted?
    # FutureMessage is delivery intent only; update/create only when intent changes.
    create_future_messages
    end

    def create_future_messages
      dp = deceased_person
      cp = contact_person
      send_date = calculate_reminder_date(dp.name, dp.hebrew_month_of_death, dp.hebrew_day_of_death)
    delivery_method = calculate_delivery_method
    email = cp.email
    phone = cp.phone

    future_message = future_messages.first
    if future_message
      changes = {}
      changes[:send_date] = send_date if future_message.send_date != send_date
      changes[:delivery_method] = delivery_method if future_message.delivery_method != delivery_method.to_s
      changes[:email] = email if future_message.email != email
      changes[:phone] = phone if future_message.phone != phone

      future_message.update!(changes) if changes.any?
      log_info "Reminder updated for contact: #{contact_person.name} deceased: #{dp.name} date: #{future_message.send_date}"
    else
      future_message = FutureMessage.create!(
        messageable: self,
        send_date: send_date,
        delivery_method: delivery_method,
        email: email,
        phone: phone
      )
      log_info "Reminder created for contact: #{contact_person.name} deceased: #{dp.name} date: #{future_message.send_date}"
    end
    end

    def delivery_method_name
      calculate_delivery_method
    end

    private

    def calculate_reminder_date(name, hm, hd)
      yahrzeit_date = calculate_yahrzeit_date(name, hm, hd)
      # preferrence = calculate_merged_preferences
      reminder_date = yahrzeit_date - 1.week
      if reminder_date >= Date.today
        reminder_date
      else
        Date.today
      end
    end

    def calculate_yahrzeit_date(name, hm, hd)
      # puts "@@@ before calling Hke::Heb.yahrzeit_date"
      Hke::Heb.yahrzeit_date(name, hm, hd)
      # puts "@@@ after calling Hke::Heb.yahrzeit_date: #{result}"
    end

    def calculate_delivery_method
      # You can adjust this logic to return the correct delivery method based on preferences
      :sms # This should return one of the enum symbols, e.g., :email, :sms, :whatsapp
    end
  end
end
