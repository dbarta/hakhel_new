module Hke
  class Preference < ApplicationRecord
    belongs_to :preferring, polymorphic: true

    validate :validate_time_presence_for_system
    validate :validate_effective_time_ordering
    validate :validate_days_before_array
    validate :validate_delivery_priority_array

    private

    # ---------- TYPE ----------

    def system_pref?
      preferring_type == "Hke::System"
    end

    def community_pref?
      preferring_type == "Hke::Community"
    end

    def system_preference
      return @system_preference if defined?(@system_preference)
      @system_preference = Hke::System.first&.preference
    end

    # ---------- TIME ----------

    def validate_time_presence_for_system
      return unless system_pref?

      errors.add(:daily_sweep_job_time, :blank) if daily_sweep_job_time.blank?
      errors.add(:send_window_start_time, :blank) if send_window_start_time.blank?
    end

    def effective_sweep_time
      return daily_sweep_job_time if daily_sweep_job_time.present?
      return nil unless community_pref?
      system_preference&.daily_sweep_job_time
    end

    def effective_send_window_start_time
      return send_window_start_time if send_window_start_time.present?
      return nil unless community_pref?
      system_preference&.send_window_start_time
    end

    def validate_effective_time_ordering
      sweep = system_pref? ? daily_sweep_job_time : effective_sweep_time
      send_start = system_pref? ? send_window_start_time : effective_send_window_start_time
      return if sweep.blank? || send_start.blank?
      return if sweep < send_start

      errors.add(:send_window_start_time, :after_sweep)
    end

    # ---------- DELIVERY ----------

    def validate_delivery_priority_array
      raw = delivery_priority

      if raw.nil?
        errors.add(:delivery_priority, :required) if system_pref?
        return
      end

      unless raw.is_a?(Array)
        errors.add(:delivery_priority, :not_array)
        return
      end

      values = raw.map { |v| v.is_a?(String) ? v.strip : v }
                  .reject(&:blank?)
                  .map(&:to_s)

      # at least one value
      if system_pref? && values.empty?
        errors.add(:delivery_priority, :required)
      end

      if community_pref? && raw.present? && values.empty?
        errors.add(:delivery_priority, :required)
      end

      # allowed set
      allowed = %w[sms whatsapp email]
      bad = values - allowed
      errors.add(:delivery_priority, :invalid_values, bad: bad.join(", ")) if bad.any?

      # uniqueness across the 3 boxes
      if values.uniq.length != values.length
        errors.add(:delivery_priority, :duplicate)
      end
    end

    # ---------- DAYS ----------

    def validate_days_before_array
      raw = how_many_days_before_yahrzeit_to_send_message

      if raw.nil?
        errors.add(:how_many_days_before_yahrzeit_to_send_message, :required) if system_pref?
        return
      end

      unless raw.is_a?(Array)
        errors.add(:how_many_days_before_yahrzeit_to_send_message, :not_array)
        return
      end

      cleaned = raw.map { |v| v.is_a?(String) ? v.strip : v }
                   .reject(&:blank?)

      if cleaned.empty? && system_pref?
        errors.add(:how_many_days_before_yahrzeit_to_send_message, :required)
        return
      end

      if cleaned.size > 4
        errors.add(:how_many_days_before_yahrzeit_to_send_message, :too_many)
      end

      cleaned.each do |value|
        int_value = Integer(value) rescue nil
        unless int_value && int_value.between?(0, 60)
          errors.add(:how_many_days_before_yahrzeit_to_send_message, :range)
        end
      end
    end
  end
end
