module Hke
  class Preference < ApplicationRecord
    include Hke::LogModelEvents

    belongs_to :preferring, polymorphic: true

    validate :validate_time_presence_for_system
    validate :validate_effective_time_ordering
    validate :validate_days_before_array
    validate :validate_delivery_priority_array

    after_commit :handle_operational_changes
    after_commit :reschedule_community_sweep, if: :community_pref?

    private

    # Override LogModelEvents to supply the correct community_id.
    # System prefs have no tenant set, so we must resolve it explicitly.
    def log_model_event(event_type, data)
      cid = case preferring
      when Hke::Community then preferring.id
      when Hke::Relation then preferring.community_id
      end
      # For system prefs cid is nil — log once per community so each sees it.
      if cid
        Hke::Logger.log(event_type: event_type, entity: self, community_id: cid, details: data)
      else
        ActsAsTenant.without_tenant do
          Hke::Community.pluck(:id, :name).each do |id, _name|
            Hke::Logger.log(event_type: event_type, entity: self, community_id: id, details: data)
          end
        end
      end
    end

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
      ActsAsTenant.without_tenant do
        case preferring
        when Hke::Relation
          preferring.future_messages.count
        when Hke::Community
          # Only count if effective value actually changes
          system_pref = Hke::System.first&.preference
          changed_impact = changes_to_save.keys & IMPACT_FIELDS
          actually_changed = changed_impact.select do |field|
            old_val = public_send("#{field}_was")
            new_val = public_send(field)
            effective_old = value_present?(old_val) ? old_val : system_pref&.public_send(field)
            effective_new = value_present?(new_val) ? new_val : system_pref&.public_send(field)
            effective_old != effective_new
          end
          actually_changed.any? ? Hke::FutureMessage.where(community_id: preferring.id).count : 0
        when Hke::System
          # Only count FutureMessages in communities that inherit the changed fields
          changed_impact = changes_to_save.keys & IMPACT_FIELDS
          affected_community_ids = Hke::Community.pluck(:id).select do |cid|
            community_pref = Hke::Preference.find_by(preferring_type: "Hke::Community", preferring_id: cid)
            changed_impact.any? { |f| !value_present?(community_pref&.public_send(f)) }
          end
          affected_community_ids.any? ? Hke::FutureMessage.where(community_id: affected_community_ids).count : 0
        else
          0
        end
      end
    end

    # -------------------------
    # after_commit handler
    # -------------------------

    def handle_operational_changes
      puts "=== PREF after_commit fired id=#{id} type=#{preferring_type}"
      changed = previous_changes.keys
      puts "=== PREF changed keys: #{changed.inspect}"

      changed_impact = changed & IMPACT_FIELDS
      if changed_impact.any?
        case preferring
        when Hke::System
          enqueue_system_rebuild_selectively(changed_impact)
        when Hke::Community
          enqueue_community_rebuild_selectively(changed_impact)
        when Hke::Relation
          Hke::FutureMessageRebuildJob.perform_async("relation", preferring.id)
          log_rebuild_decision(
            community: preferring.community,
            decision: "rebuild",
            reason: "relation preference changed: #{changed_impact.join(", ")}"
          )
        end
      end

      # ---- reschedule sweep ----
      if changed.include?("daily_sweep_job_time")
        puts "=== PREF sweep time changed — rescheduling"

        case preferring
        when Hke::Community
          preferring.send(:schedule_daily_job)
        when Hke::System
          Hke::Community.find_each { |c| c.send(:schedule_daily_job) }
        end
      end
    end

    # When a system pref changes, only rebuild communities whose effective
    # value actually changes (i.e. the community does NOT override the field).
    def enqueue_system_rebuild_selectively(changed_fields)
      ActsAsTenant.without_tenant do
        Hke::Community.find_each do |community|
          community_pref = Hke::Preference.find_by(preferring: community)

          # A community is affected if, for ANY changed impact field,
          # its own preference is nil (meaning it inherits from system).
          overridden_fields = []
          inherited_fields = []

          changed_fields.each do |field|
            community_val = community_pref&.public_send(field)
            if community_val.present?
              overridden_fields << field
            else
              inherited_fields << field
            end
          end

          if inherited_fields.any?
            Hke::FutureMessageRebuildJob.perform_async("community", community.id)
            log_rebuild_decision(
              community: community,
              decision: "rebuild",
              reason: "system pref changed #{inherited_fields.join(", ")}; " \
                      "community inherits these (no local override)"
            )
          else
            log_rebuild_decision(
              community: community,
              decision: "skip",
              reason: "system pref changed #{changed_fields.join(", ")}; " \
                      "community overrides all: #{overridden_fields.join(", ")}"
            )
          end
        end
      end
    end

    # When a community pref changes, only rebuild if the effective value
    # actually changed. If the community value was already overriding the
    # system value, and the new value is different, rebuild. If the community
    # clears a field (sets to nil), the effective value now falls through to
    # system — that's also a change worth rebuilding.
    def enqueue_community_rebuild_selectively(changed_fields)
      system_pref = Hke::System.first&.preference

      actually_changed = changed_fields.select do |field|
        old_val, new_val = previous_changes[field]
        # Effective old = old_val if present, else system fallback
        effective_old = value_present?(old_val) ? old_val : system_pref&.public_send(field)
        # Effective new = new_val if present, else system fallback
        effective_new = value_present?(new_val) ? new_val : system_pref&.public_send(field)
        effective_old != effective_new
      end

      if actually_changed.any?
        Hke::FutureMessageRebuildJob.perform_async("community", preferring.id)
        log_rebuild_decision(
          community: preferring,
          decision: "rebuild",
          reason: "community pref changed #{actually_changed.join(", ")}; " \
                  "effective value differs from before"
        )
      else
        log_rebuild_decision(
          community: preferring,
          decision: "skip",
          reason: "community pref changed #{changed_fields.join(", ")}; " \
                  "effective value unchanged (same as system default)"
        )
      end
    end

    def value_present?(val)
      return false if val.nil?
      return val.reject(&:blank?).any? if val.is_a?(Array)
      val.present?
    end

    def log_rebuild_decision(community:, decision:, reason:)
      puts "=== PREF rebuild #{decision} for community #{community&.id}: #{reason}"
      ActsAsTenant.without_tenant do
        Hke::Logger.log(
          event_type: "pref_rebuild_decision",
          entity: self,
          community_id: community&.id,
          details: {
            decision: decision,
            community_id: community&.id,
            community_name: community&.name,
            preferring_type: preferring_type,
            reason: reason
          }
        )
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
