module Hke
  class PortalChange < CommunityRecord
    belongs_to :contact_person, class_name: "Hke::ContactPerson"

    enum :change_type, { profile: "profile", deceased: "deceased", preference: "preference" }

    validates :change_type, :changed_at, :community_id, presence: true
  end
end
