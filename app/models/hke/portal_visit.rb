module Hke
  class PortalVisit < CommunityRecord
    belongs_to :contact_person, class_name: "Hke::ContactPerson"

    validates :visited_at, :community_id, presence: true
  end
end
