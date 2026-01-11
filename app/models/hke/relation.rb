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
      future_messages.destroy_all
      create_future_messages
    end

    def create_future_messages
      dp = deceased_person
      cp = contact_person
      send_date = calculate_reminder_date(dp.name, dp.hebrew_month_of_death, dp.hebrew_day_of_death)
      snippets = generate_hebrew_snippets(self, [:sms], reference_date: send_date)
      fm = FutureMessage.create!(
        messageable: self, # Changed relation to messageable since it is polymorphic
        send_date: send_date, # Changed send_at to send_date, assuming it matches the column name
        full_message: snippets[:sms],
        delivery_method: calculate_delivery_method, # This will set the delivery_method enum
        email: cp.email,
        phone: cp.phone,
        deceased_first_name: dp.first_name,
        deceased_last_name: dp.last_name,
        date_of_death: dp.date_of_death,
        contact_first_name: cp.first_name,
        contact_last_name: cp.last_name,
        hebrew_year_of_death: dp.hebrew_year_of_death,
        hebrew_month_of_death: dp.hebrew_month_of_death,
        hebrew_day_of_death: dp.hebrew_day_of_death,
        relation_of_deceased_to_contact: relation_of_deceased_to_contact,
      )
      log_info "Reminder for contact: #{contact_person.name}  deceased: #{dp.name} date: #{fm.send_date}"
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
      # puts "@@@ before calling Hke.yahrzeit_date"
      Hke.yahrzeit_date(name, hm, hd)
      # puts "@@@ after calling Hke.yahrzeit_date: #{result}"
    end

    def calculate_delivery_method
      # You can adjust this logic to return the correct delivery method based on preferences
      :sms # This should return one of the enum symbols, e.g., :email, :sms, :whatsapp
    end
  end
end
