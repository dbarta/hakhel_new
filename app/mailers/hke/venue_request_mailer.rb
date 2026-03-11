module Hke
  class VenueRequestMailer < ApplicationMailer
    def notify_admin(venue_request)
      @venue_request = venue_request
      @venue = venue_request.community_venue
      @contact = venue_request.contact_person
      @relation = venue_request.relation
      @community = ActsAsTenant.without_tenant { @venue.community }

      admin_email = @community.account&.owner&.email
      return unless admin_email.present?

      mail(
        to: admin_email,
        subject: "בקשה חדשה לשירות קהילתי: #{@venue.title}"
      )
    end
  end
end
