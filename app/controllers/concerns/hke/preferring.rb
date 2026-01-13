module Hke
  module Preferring
    extend ActiveSupport::Concern

    included do
      has_one :preference, as: :preferring, class_name: "Hke::Preference", dependent: :destroy
      accepts_nested_attributes_for :preference
    end

    def preference_attributes=(attributes)
      if preference
        preference.assign_attributes(attributes)
      else
        # attributes = attributes.merge(preferring: self)
        build_preference(attributes)
      end
    end

    class_methods do
      def polymorphic_name
        name # this is the class name such as "Hke::Cemetery"
      end
    end
  end
end
