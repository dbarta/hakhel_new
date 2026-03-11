module Hke
  module Portal
    class VenuesController < BaseController
      def index
        @venues = Hke::CommunityVenue.active
        @submitted_venue_ids = @contact.venue_requests.pluck(:community_venue_id).to_set
      end

      def request_venue
        @venue = Hke::CommunityVenue.find(params[:venue_id])
        relation_id = params[:relation_id].presence

        existing = @contact.venue_requests.find_by(community_venue_id: @venue.id)
        if existing
          redirect_to portal_venues_path(@portal_token), notice: t("hke.portal.venues.already_requested")
          return
        end

        request = @contact.venue_requests.build(
          community_venue: @venue,
          relation_id: relation_id,
          community_id: @contact.community_id
        )

        if request.save
          redirect_to portal_venues_path(@portal_token), notice: t("hke.portal.venues.request_sent")
        else
          redirect_to portal_venues_path(@portal_token), alert: t("hke.portal.venues.request_failed")
        end
      end
    end
  end
end
