# frozen_string_literal: true

module Hke
  class PreferenceResolver
    Resolved = Struct.new(
      :how_many_days_before_yahrzeit_to_send_message,
      :delivery_priority,
      :enable_fallback_delivery_method,
      :daily_sweep_job_time,
      :time_zone,
      keyword_init: true
    )

    def self.resolve(preferring:)
      new(preferring).resolve
    end

    def initialize(preferring)
      @preferring = preferring
    end

    def resolve
      prefs = preference_chain

      Resolved.new(
        how_many_days_before_yahrzeit_to_send_message: pick(prefs, :how_many_days_before_yahrzeit_to_send_message),
        delivery_priority: pick(prefs, :delivery_priority),
        enable_fallback_delivery_method: pick(prefs, :enable_fallback_delivery_method),
        daily_sweep_job_time: pick(prefs, :daily_sweep_job_time),
        time_zone: pick(prefs, :time_zone)
      )
    end

    private

    attr_reader :preferring

    # Most specific -> least specific
    def preference_chain
      [
        preference_for(preferring),
        preference_for(parent_of(preferring)),
        preference_for(system)
      ].compact
    end

    def pick(prefs, field)
      prefs.each do |p|
        v = p.public_send(field)
        return v unless v.nil?
      end
      nil
    end

    def preference_for(obj)
      return nil if obj.nil?
      return obj.preference if obj.respond_to?(:preference)
      Hke::Preference.find_by(preferring: obj)
    end

    def parent_of(obj)
      return nil if obj.nil?
      return obj.community if obj.respond_to?(:community) && obj.community.present? # ActsAsTenant
      nil
    end

    def system
      Hke::System.instance
    end
  end
end
