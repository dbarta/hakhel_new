module Hke
  class Cemetery < CommunityRecord
    include Hke::Addressable
    include Hke::Deduplicatable
    deduplication_fields :name
    validates :name, presence: {message: :presence}
  end
end
