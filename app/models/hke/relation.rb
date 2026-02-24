module Hke
  class Relation < CommunityRecord
    include Hke::Deduplicatable
    include Hke::LogModelEvents
    include Hke::MessageGenerator

    deduplication_fields :deceased_person_id, :contact_person_id

    belongs_to :deceased_person
    belongs_to :contact_person
    has_many :future_messages, as: :messageable, dependent: :destroy
    has_many :sent_messages, as: :messageable
    has_many :relations_selections
    has_many :selections, through: :relations_selections
    has_one :preference, as: :preferring, dependent: :destroy

    has_secure_token length: 24

    accepts_nested_attributes_for :contact_person, reject_if: :all_blank
    accepts_nested_attributes_for :deceased_person, reject_if: :all_blank

    after_commit :process_future_messages

    def contact_person_attributes=(attributes)
      if attributes["phone"].present?
        self.contact_person = ContactPerson.find_or_initialize_by(phone: attributes["phone"])
        contact_person.assign_attributes(attributes)
      end
    end

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
      create_future_messages
    end

    def create_future_messages
      dp = deceased_person
      cp = contact_person

      resolved = Hke::PreferenceResolver.resolve(preferring: self)

      yahrzeit_date = calculate_yahrzeit_date(
        dp.name,
        dp.hebrew_month_of_death,
        dp.hebrew_day_of_death
      )

      offsets = Array(resolved.how_many_days_before_yahrzeit_to_send_message)
        .compact.map(&:to_i).uniq.sort
      offsets = [7] if offsets.empty?

      send_date = next_send_date_from_offsets(
        dp.name,
        dp.hebrew_month_of_death,
        dp.hebrew_day_of_death,
        yahrzeit_date,
        offsets
      )

      delivery_method = select_usable_delivery_method(
        Array(resolved.delivery_priority),
        cp
      )

      email = cp.email
      phone = cp.phone

      future_message = future_messages.first

      # ---- structured build log (stable + minimal) ----
      Hke::Logger.log(
        event_type: "future_message_build",
        entity: self,
        details: {
          mode: future_message ? "update" : "create",
          relation_id: id,
          contact_id: cp.id,
          deceased_id: dp.id,
          yahrzeit_date: yahrzeit_date,
          offsets: offsets,
          computed_send_date: send_date,
          delivery_priority: resolved.delivery_priority,
          chosen_delivery_method: delivery_method,
          email_present: email.present?,
          phone_present: phone.present?
        }
      )

      if future_message
        changes = {}
        changes[:send_date] = send_date if future_message.send_date != send_date
        changes[:delivery_method] = delivery_method if future_message.delivery_method.to_s != delivery_method.to_s
        changes[:email] = email if future_message.email != email
        changes[:phone] = phone if future_message.phone != phone
        future_message.update!(changes) if changes.any?
      else
        FutureMessage.create!(
          messageable: self,
          send_date: send_date,
          delivery_method: delivery_method,
          email: email,
          phone: phone
        )
      end
    end

    def delivery_method_name
      calculate_delivery_method
    end

    private

    def next_send_date_from_offsets(name, hm, hd, yahrzeit_date, offsets)
      today = Time.zone.today

      # If a message was already sent today, don't schedule another for today
      already_sent_today = sent_messages
        .where(send_date: today.beginning_of_day..today.end_of_day)
        .exists?
      min_date = already_sent_today ? today.tomorrow : today

      candidate = offsets.sort.map { |d| yahrzeit_date - d.days }.find { |dt| dt >= min_date }
      return candidate if candidate

      next_yahrzeit = calculate_yahrzeit_date(name, hm, hd).next_year
      offsets.sort.map { |d| next_yahrzeit - d.days }.find { |dt| dt >= min_date } || min_date
    end

    def calculate_yahrzeit_date(name, hm, hd)
      Hke::Heb.yahrzeit_date(name, hm, hd)
    end

    def calculate_delivery_method
      :sms
    end

    def select_usable_delivery_method(priority_list, contact)
      methods = Array(priority_list).map(&:to_sym)

      methods.each do |m|
        case m
        when :email
          return :email if contact.email.present?
        when :sms
          return :sms
        when :whatsapp
          return :whatsapp if contact.phone.present?
        end
      end

      :sms
    end
  end
end
