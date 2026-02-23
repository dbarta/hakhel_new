module Hke
  class Preference < ApplicationRecord
    belongs_to :preferring, polymorphic: true

    validate :validate_time_presence_for_system
    validate :validate_effective_time_ordering
    validate :validate_days_before_array
    validate :validate_delivery_priority_array

    after_commit :handle_operational_changes
    after_commit :reschedule_community_sweep, if: :community_pref?

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

      if system_pref? && values.empty?
        errors.add(:delivery_priority, :required)
      end

      if community_pref? && raw.present? && values.empty?
        errors.add(:delivery_priority, :required)
      end

      allowed = %w[sms whatsapp email]
      bad = values - allowed
      errors.add(:delivery_priority, :invalid_values, bad: bad.join(", ")) if bad.any?

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
        int_value = begin
          Integer(value)
        rescue
          nil
        end

        unless int_value && int_value.between?(0, 60)
          errors.add(:how_many_days_before_yahrzeit_to_send_message, :range)
        end
      end
    end

    # -------------------------
    # Operational change handling
    # -------------------------

    IMPACT_FIELDS = %w[
      how_many_days_before_yahrzeit_to_send_message
      delivery_priority
    ].freeze

    def impactful_rebuild_change?
      puts "@@@@@@@@@@@@@@@@ in impactful_rebuild_change? keys: #{changes_to_save.keys} IMPACT_FIELDS: #{IMPACT_FIELDS}"
      (changes_to_save.keys & IMPACT_FIELDS).any?
    end

    def rebuild_scope_descriptor
      case preferring
      when Hke::Relation
        ["relation", preferring.id]
      when Hke::Community
        ["community", preferring.id]
      when Hke::System
        ["system", nil]
      else
        [nil, nil]
      end
    end

    def rebuild_impact_count
      counter = lambda do
        case preferring
        when Hke::Relation
          preferring.future_messages.count
        when Hke::Community
          Hke::FutureMessage.where(community_id: preferring.id).count
        when Hke::System
          Hke::FutureMessage.count
        else
          0
        end
      end

      # Hke::* records are tenant-scoped via ActsAsTenant. For an impact preview/count we
      # want to be independent of the current tenant (especially for system prefs).
      count = if defined?(ActsAsTenant) && ActsAsTenant.respond_to?(:without_tenant)
        ActsAsTenant.without_tenant { counter.call }
      else
        counter.call
      end
      puts "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ in rebuild_impact_count, prefering: #{preferring}, count = #{count}"
      count
    end

    # -------------------------
    # DEBUGGED handler
    # -------------------------

    def handle_operational_changes
      puts "=== PREF after_commit fired id=#{id} type=#{preferring_type}"
      changed = previous_changes.keys
      puts "=== PREF changed keys: #{changed.inspect}"

      # ---- rebuild ----
      if (changed & IMPACT_FIELDS).any?
        mode, id = rebuild_scope_descriptor
        puts "=== PREF enqueue rebuild #{mode}/#{id}"
        Hke::FutureMessageRebuildJob.perform_async(mode, id) if mode
      end

      # ---- reschedule sweep ----
      if changed.include?("daily_sweep_job_time")
        puts "=== PREF sweep time changed — rescheduling"

        case preferring
        when Hke::Community
          puts "=== PREF calling schedule_daily_job for community #{preferring.id}"
          preferring.send(:schedule_daily_job)
        when Hke::System
          puts "=== PREF system sweep change — rescheduling ALL communities"
          Hke::Community.find_each { |c| c.send(:schedule_daily_job) }
        end
      end
    end

    # -------------------------
    # community-only callback
    # -------------------------

    def reschedule_community_sweep
      puts "=== PREF reschedule_community_sweep fired for #{preferring_type}"
      return unless preferring.respond_to?(:schedule_daily_job)

      preferring.schedule_daily_job
    end
  end
end
