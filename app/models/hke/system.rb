module Hke
  class System < ApplicationRecord
    include Hke::SystemInfoConcern
    include Hke::Preferring

    # Singleton pattern to ensure only one instance of System
    def self.instance
      first_or_create
    end

    def preference
      super
    end

    # Method for search_results partial
    def preference_summary
      pref = preference
      return "לא הוגדר" unless pref

      enabled = []
      enabled << "אימייל" if pref.enable_send_email?
      enabled << "SMS" if pref.enable_send_sms?
      enabled << "WhatsApp" if pref.enable_send_whatsapp?

      enabled.empty? ? "כל השירותים כבויים" : enabled.join(", ")
    end
  end
end
