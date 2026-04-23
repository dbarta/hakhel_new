module Hke
  module Admin
    class DashboardController < ApplicationController
      layout "hke/dashboard"
      before_action :authenticate_user!

      # Skip Pundit callbacks for dashboard since it doesn't use policies
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      def show
        unless current_user.system_admin?
          redirect_to root_path, alert: t("admin.dashboard.access_denied")
          return
        end

        # Returning to System Admin dashboard clears any selected community scope
        session[:selected_community_id] = nil

        thirty_days_ago = 30.days.ago
        thirty_days_from_now = 30.days.from_now

        ActsAsTenant.without_tenant do
          @total_communities    = Hke::Community.count
          @total_contacts       = Hke::ContactPerson.count
          @total_deceased       = Hke::DeceasedPerson.count
          @messages_sent_30_days = Hke::SentMessage.where(created_at: thirty_days_ago..Time.current).count

          communities = Hke::Community.order(:name).to_a

          @communities_with_stats = communities.map do |community|
            contacts_count = Hke::ContactPerson.where(community_id: community.id).count
            deceased_count = Hke::DeceasedPerson.where(community_id: community.id).count
            sent_30d       = Hke::SentMessage.where(community_id: community.id, created_at: thirty_days_ago..Time.current).count
            upcoming_30d   = Hke::FutureMessage.where(community_id: community.id, send_date: Time.current..thirty_days_from_now).count
            not_sent_30d   = Hke::NotSentMessage.where(community_id: community.id, created_at: thirty_days_ago..Time.current).count
            total_30d      = sent_30d + not_sent_30d
            success_rate   = total_30d > 0 ? (sent_30d.to_f / total_30d * 100).round(1) : nil
            last_sent_at   = Hke::SentMessage.where(community_id: community.id).maximum(:created_at)
            admin_name     = User.where(community_id: community.id, community_admin: true).pick(:name) || "—"

            status = if last_sent_at.nil?
              "new"
            elsif last_sent_at < 30.days.ago
              "stalled"
            else
              "active"
            end

            issues = []
            issues << :low_success_rate    if success_rate && success_rate < 75
            issues << :no_upcoming_messages if upcoming_30d == 0 && status != "new"
            issues << :stalled              if status == "stalled"

            {
              community:      community,
              contacts_count: contacts_count,
              deceased_count: deceased_count,
              sent_30d:       sent_30d,
              upcoming_30d:   upcoming_30d,
              success_rate:   success_rate,
              last_sent_at:   last_sent_at,
              admin_name:     admin_name,
              status:         status,
              issues:         issues
            }
          end

          @communities_needing_attention = @communities_with_stats.select { |cs| cs[:issues].any? }
        end
      end

      public

      def switch_to_community
        unless current_user.system_admin?
          redirect_to root_path, alert: "Access denied."
          return
        end

        community_id = params[:community_id]
        if community_id.present?
          community = Hke::Community.find(community_id)
          session[:selected_community_id] = community.id
          redirect_to hke_root_path
        else
          session[:selected_community_id] = nil
          redirect_to hke_admin_root_path
        end
      end
    end
  end
end
