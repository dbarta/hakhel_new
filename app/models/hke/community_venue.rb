module Hke
  class CommunityVenue < CommunityRecord
    enum :venue_type, {kaddish: "kaddish", seudah: "seudah", custom: "custom"}

    has_many :venue_requests, class_name: "Hke::VenueRequest", dependent: :destroy

    validates :venue_type, :title, presence: true

    scope :active, -> { where(active: true) }
  end
end
