
module Hke
  module SetCommunityAsTenant
    extend ActiveSupport::Concern

    included do
      before_action :set_community_as_current_tenant
    end

    private

    # Single source of truth for tenant scoping across all HKE controllers
    def set_community_as_current_tenant
      return unless user_signed_in?
      ActsAsTenant.current_tenant = hardwired_community if defined?(ActsAsTenant)
    end

    def hardwired_community
      @hardwired_community ||= Hke::Community.find_by!(name: "Kfar Vradim Synagogue")
    end
  end
end
