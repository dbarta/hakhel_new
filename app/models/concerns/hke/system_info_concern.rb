# app/models/concerns/hke/system_info_concern.rb
module Hke
  module SystemInfoConcern
    extend ActiveSupport::Concern
    SYSTEM_INFO_CACHE_KEY = "system_info_with_preferences".freeze

    class_methods do
      def system_info
        Rails.cache.fetch(SYSTEM_INFO_CACHE_KEY, expires_in: 12.days) do
          {
            product_name: Hke::System.instance.product_name,
            version: Hke::System.instance.version,
            preferences: Hke::System.instance.preference&.attributes&.except("id", "preferring_id", "preferring_type", "created_at", "updated_at")
          }
        end
      end

      def clear_system_info_cache
        Rails.cache.delete(SYSTEM_INFO_CACHE_KEY)
      end
    end

    def system_info
      self.class.system_info
    end

    def clear_system_info_cache
      self.class.clear_system_info_cache
    end
  end
end
