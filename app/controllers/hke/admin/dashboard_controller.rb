module Hke
  module Admin
    class DashboardController < ApplicationController
      before_action :authenticate_user!

      # Skip Pundit callbacks for dashboard since it doesn't use policies
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      def show
        # Check authorization manually for dashboard
        unless current_user.system_admin?
          redirect_to root_path, alert: t("admin.dashboard.access_denied")
          return
        end

        # Returning to System Admin dashboard should clear any selected community scope
        session[:selected_community_id] = nil

        @total_communities = Hke::Community.count
        @total_users = User.count
        @total_community_admins = User.community_admin.count

        # Message statistics for last 30 days and next 30 days
        thirty_days_ago = 30.days.ago
        thirty_days_from_now = 30.days.from_now

        ActsAsTenant.without_tenant do
          @messages_sent_30_days = Hke::SentMessage.where(created_at: thirty_days_ago..Time.current).count
          @messages_to_send_30_days = Hke::FutureMessage.where(send_date: Time.current..thirty_days_from_now).count
        end
      end

      def switch_to_community
        unless current_user.system_admin?
          redirect_to root_path, alert: "Access denied."
          return
        end

        community_id = params[:community_id]
        if community_id.present?
          community = Hke::Community.find(community_id)
          session[:selected_community_id] = community.id
          redirect_to hke_root_path # , notice: t('admin.dashboard.community_switching.switched_to_community', community: community.name)
        else
          session[:selected_community_id] = nil
          redirect_to hke_admin_root_path # , notice: t('admin.dashboard.community_switching.returned_to_system_admin')
        end
      end
    end
  end
end
