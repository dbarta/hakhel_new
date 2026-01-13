module Hke
  class Address < ApplicationRecord
    self.table_name = "hke_addresses"

    belongs_to :addressable, polymorphic: true

    validates :addressable, presence: true
  end
end
