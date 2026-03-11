module Hke
  class VenueRequest < CommunityRecord
    enum :status, {pending: "pending", confirmed: "confirmed", declined: "declined"}

    belongs_to :contact_person, class_name: "Hke::ContactPerson"
    belongs_to :community_venue, class_name: "Hke::CommunityVenue"
    belongs_to :relation, class_name: "Hke::Relation", optional: true

    validates :contact_person, :community_venue, presence: true

    after_create_commit :notify_admin

    private

    def notify_admin
      Hke::VenueRequestMailer.notify_admin(self).deliver_later
    end
  end
end
