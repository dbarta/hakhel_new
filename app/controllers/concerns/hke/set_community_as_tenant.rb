
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
      return unless defined?(ActsAsTenant)
      community = if current_user.system_admin? && session[:selected_community_id].present?
        Hke::Community.find_by(id: session[:selected_community_id])
      elsif current_user.system_admin?
        # API scripts (no session): fall back to first community
        Hke::Community.first
      else
        current_user.community
      end
      ActsAsTenant.current_tenant = community if community
    end
  end
end
