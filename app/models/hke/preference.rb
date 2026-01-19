module Hke
  class Preference < ApplicationRecord
    belongs_to :preferring, polymorphic: true

    validate :validate_delivery_priority
    validate :validate_yahrzeit_offsets

    private

    def validate_delivery_priority
      return if delivery_priority.nil?

      unless delivery_priority.is_a?(Array)
        errors.add(:delivery_priority, "must be an array")
        return
      end

      if delivery_priority.empty?
        errors.add(:delivery_priority, "cannot be empty")
      end

      allowed = %w[sms whatsapp email]
      bad = delivery_priority - allowed
      if bad.any?
        errors.add(:delivery_priority, "contains invalid values: #{bad.join(', ')}")
      end
    end

    def validate_yahrzeit_offsets
      return if how_many_days_before_yahrzeit_to_send_message.nil?

      unless how_many_days_before_yahrzeit_to_send_message.is_a?(Array)
        errors.add(:how_many_days_before_yahrzeit_to_send_message, "must be an array")
        return
      end

      if how_many_days_before_yahrzeit_to_send_message.empty?
        errors.add(:how_many_days_before_yahrzeit_to_send_message, "cannot be empty")
      end

      bad = how_many_days_before_yahrzeit_to_send_message.reject { |d| d.is_a?(Integer) && d >= 0 }
      if bad.any?
        errors.add(:how_many_days_before_yahrzeit_to_send_message, "must contain non-negative integers")
      end
    end
  end
end
