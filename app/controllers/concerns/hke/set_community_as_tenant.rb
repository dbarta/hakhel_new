module Hke
  module SetCommunityAsTenant
    extend ActiveSupport::Concern

    included do
      before_action :set_community_as_current_tenant
    end

    def set_community_as_current_tenant
      # Temporarily setting the tenant to the "Kfar Vradim Synagogue" community
      community = Hke::Community.find_by(name: "Kfar Vradim Synagogue")
      if community
        ActsAsTenant.current_tenant = community
      else
        # Handle if the community is not found
        raise "Community 'Kfar Vradim Synagogue' not found"
      end
    end
  end
end
