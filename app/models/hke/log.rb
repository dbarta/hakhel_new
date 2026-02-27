module Hke
  class Log < Hke::ApplicationRecord
    belongs_to :user, optional: true
    belongs_to :community, optional: true

    validates :event_type, :event_time, presence: true
  end
end
