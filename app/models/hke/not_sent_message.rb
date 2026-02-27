module Hke
  class NotSentMessage < CommunityRecord
    belongs_to :messageable, polymorphic: true

    enum :reason, {
      not_approved: 0,
      delivery_failed: 1,
      no_contact_info: 2,
      opt_out: 3,
      no_delivery_method: 4
    }

    enum :delivery_method, {
      no_delivery: 0,
      email: 1,
      sms: 2,
      whatsapp: 4
    }

    validates :reason, presence: true
    validates :send_date, presence: true

    scope :filter_by_date_range, ->(start_date, end_date) {
      return all if start_date.blank? && end_date.blank?
      where("send_date BETWEEN ? AND ?", start_date || 100.years.ago, end_date || 100.years.from_now)
    }

    # Human-readable reason in Hebrew
    def reason_text
      I18n.t("message_management.not_sent_reasons.#{reason}", default: reason.humanize)
    end
  end
end

