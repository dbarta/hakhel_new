module Hke
  class FutureMessage < CommunityRecord
    # Approval system
    attribute :approval_status, :integer, default: 0
    enum :approval_status, {
      pending: 0,
      approved: 1,
      rejected: 2
    }

    include Hke::Loggable
    include Hke::LogModelEvents

    belongs_to :messageable, polymorphic: true
    belongs_to :approved_by, class_name: 'User', optional: true
    has_secure_token :token

    # Enum for delivery method
    enum :delivery_method, {
      no_delivery: 0,
      email: 1,
      sms: 2,
      whatsapp: 4
    }

    # Scopes (unchanged – they are delivery-related)
    scope :for_current_week, -> {
      week_start = Date.current.beginning_of_week(:sunday)
      week_end   = Date.current.end_of_week(:saturday)
      where(send_date: week_start..week_end).order(:send_date)
    }

    scope :pending_approval,  -> { where(approval_status: :pending) }
    scope :approved_messages, -> { where(approval_status: :approved) }
    scope :rejected_messages, -> { where(approval_status: :rejected) }

    scope :in_next_week,     -> { where(send_date: Time.current..1.week.from_now) }
    scope :in_next_two_weeks,-> { where(send_date: Time.current..2.weeks.from_now) }
    scope :in_next_month,    -> { where(send_date: Time.current..1.month.from_now) }
    scope :future_messages,  -> { where('send_date >= ?', Time.current) }

    validates :send_date, presence: true
    validate  :send_date_must_be_in_the_future
    validates :delivery_method, presence: true
    validates :email, presence: true, if: -> { delivery_method == "email" }
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }
    validates :phone, presence: true, if: -> { %w[sms whatsapp phone].include?(delivery_method) }

    # Enqueue delivery
    def blast
      log_info "Enqueuing delivery job for #{self}"
      Hke::FutureMessageSendJob.perform_async(id, community_id)
    end

    # Approval methods (unchanged)
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

    private

    def send_date_must_be_in_the_future
      if send_date.present? && send_date < Date.today
        errors.add(:send_date, "must be in the future")
      end
    end
  end
end
