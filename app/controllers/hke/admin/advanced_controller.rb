module Hke
  module Admin
    class AdvancedController < ApplicationController
      before_action :authenticate_user!
      before_action :require_system_admin!

      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      def show
        @communities = Hke::Community.order(:name)
      end

      def run_scheduler
        community = Hke::Community.find(params[:community_id])
        Hke::FutureMessageCommunityDailySchedulerJob.new.perform(community.id)
        redirect_to hke_admin_advanced_path,
          notice: "המתזמן היומי הורץ עבור קהילת #{community.name}"
      rescue => e
        redirect_to hke_admin_advanced_path,
          alert: "שגיאה: #{e.message}"
      end

      def run_recovery
        community = Hke::Community.find(params[:community_id])
        Hke::FutureMessagePastDueRecoveryJob.new.perform(community.id)
        redirect_to hke_admin_advanced_path,
          notice: "שחזור הודעות שלא נשלחו הורץ עבור קהילת #{community.name}"
      rescue => e
        redirect_to hke_admin_advanced_path,
          alert: "שגיאה: #{e.message}"
      end

      private

      def require_system_admin!
        unless current_user.system_admin?
          redirect_to root_path, alert: t("admin.dashboard.access_denied")
        end
      end
    end
  end
end
