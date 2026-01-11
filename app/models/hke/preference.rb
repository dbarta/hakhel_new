module Hke
  class Preference < ApplicationRecord
    belongs_to :preferring, polymorphic: true
    validates :how_many_days_before_yahrzeit_to_send_message, presence: true
  end
end
