module Hke
  class FutureMessage < CommunityRecord
    # Approval system
    attribute :approval_status, :integer, default: 0
    enum :approval_status, {
      pending: 0,
      approved: 1,
      rejected: 2
    }

    # Scope: messages scheduled to be sent this week, tenant-scoped
    scope :for_current_week, -> {
      week_start = Date.current.beginning_of_week(:sunday)
      week_end = Date.current.end_of_week(:saturday)
      where(send_date: week_start..week_end).order(:send_date)
    }

    # Approval-related scopes
    scope :pending_approval, -> { where(approval_status: :pending) }
    scope :approved_messages, -> { where(approval_status: :approved) }
    scope :rejected_messages, -> { where(approval_status: :rejected) }

    # Time-based scopes for dashboard filters
    scope :in_next_week, -> { where(send_date: Time.current..1.week.from_now) }
    scope :in_next_two_weeks, -> { where(send_date: Time.current..2.weeks.from_now) }
    scope :in_next_month, -> { where(send_date: Time.current..1.month.from_now) }
    scope :future_messages, -> { where('send_date >= ?', Time.current) }

    include Hke::Loggable
    include Hke::LogModelEvents


    # TODO:
    # 1. delivery_method - implement as bit field, with accessor functions
    # 2. instead of send_date, use two fields: scheduled_send_date_and_time and actual_sent_date_and_time
    # 3. Include also the yarzheit date, in case the message was not sent for some reason it could still be sent.

    belongs_to :messageable, polymorphic: true
    belongs_to :approved_by, class_name: 'User', optional: true
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
    validate :send_date_must_be_in_the_future
    validates :delivery_method, presence: true
    validates :full_message, presence: true
    validates :email, presence: true, if: -> { delivery_method == "email" }
    validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}, if: -> { email.present? }
    validates :phone, presence: true, if: -> { %w[sms whatsapp phone].include?(delivery_method) }

    # Placeholder for message_type validation; clarify what message_type represents
    # validates :message_type, presence: true, inclusion: { in: [/* expected values */] }

    def blast
  log_info "Enqueuing delivery job for #{self}"
  Hke::FutureMessageSendJob.perform_async(id, community_id)
    end

    def name
      [contact_first_name, contact_last_name].compact.join(" ")
    end

    # Approval methods
    def approve!(user)
      update!(
        approval_status: :approved,
        approved_at: Time.current,
        approved_by: user
      )
    end

    def reject!(user)
      update!(
        approval_status: :rejected,
        approved_at: Time.current,
        approved_by: user
      )
    end

    def reset_approval!
      update!(
        approval_status: :pending,
        approved_at: nil,
        approved_by: nil
      )
    end

    # Get message preview for approval interface
    def message_preview(length: 100, reference_date: Time.zone.today)
      full_text = rendered_full_message(reference_date: reference_date)
      return "" if full_text.blank?

      # Extract the first part that identifies deceased, contact, and Hebrew date
      lines = full_text.split("\n")
      preview_text = lines.first(10).join(" ")

      if preview_text.length > length
        preview_text.truncate(length)
      else
        preview_text
      end
    end

    def rendered_full_message(reference_date: Time.zone.today)
      return full_message.to_s if messageable.blank? || !messageable.respond_to?(:generate_hebrew_snippets)

      snippets = messageable.generate_hebrew_snippets(
        messageable,
        [:sms],
        reference_date: reference_date
      )

      (snippets[:sms] || full_message).to_s
    rescue => e
      Rails.logger.error("Failed to render dynamic future message ##{id}: #{e.message}")
      full_message.to_s
    end

    private

    def send_date_must_be_in_the_future
      if send_date.present? && send_date < Date.today # Time.current
        errors.add(:send_date, "must be in the future")
      end
    end
  end
end
