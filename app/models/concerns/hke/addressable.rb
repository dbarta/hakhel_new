module Hke
  module Addressable
    extend ActiveSupport::Concern

    included do
      has_one :address, as: :addressable, class_name: "::Address", dependent: :destroy
      accepts_nested_attributes_for :address
    end

    def address_attributes=(attributes)
      if address
        address.assign_attributes(attributes)
      else
        attributes = attributes.merge(address_type: "billing", addressable_type: self.class.name)
        build_address(attributes)
      end
    end

    class_methods do
      def polymorphic_name
        name # this is the class name such as "Hke::Cemetery"
      end
    end
  end
end
