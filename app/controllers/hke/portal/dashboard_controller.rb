module Hke
  module Portal
    class DashboardController < BaseController
      def show
        @relations = @contact.relations.includes(:deceased_person, :future_messages)
        Hke::PortalVisit.create!(
          contact_person: @contact,
          community_id: @contact.community_id,
          visited_at: Time.current
        )
      end
    end
  end
end
