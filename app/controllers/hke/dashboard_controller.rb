module Hke
  class DashboardController < ApplicationController
    include Hke::SetCommunityAsTenant
    before_action :authenticate_user!

    # Skip Pundit callbacks for dashboard since it does role-based routing
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def show
      # Role-based dashboard routing with community switching support
      if current_user.system_admin?
        # Check if system admin has selected a specific community
        if session[:selected_community_id].present?
          show_community_admin_dashboard
        else
          redirect_to hke_admin_root_path
        end
      elsif current_user.community_admin?
        show_community_admin_dashboard
      elsif current_user.community_user?
        show_community_user_dashboard
      else
        redirect_to root_path, alert: "Access denied. Please contact administrator."
      end
    end

    private

    def show_community_admin_dashboard
      # Get time filter from params, default to one week
      @time_filter = params[:time_filter] || 'one_week'

      # Get messages based on time filter using same logic as future_messages controller
      @messages = get_filtered_messages(@time_filter)

      @pending_approvals = Hke::FutureMessage.pending_approval.limit(10)

      # Calculate stats with existing SentMessage structure
      @stats = {
        total_sent_this_week: defined?(Hke::SentMessage) ? Hke::SentMessage.where(created_at: 1.week.ago..Time.current).count : 0,
        total_failures: 0, # Will implement when we have proper status tracking
        pending_this_week: @messages.pending_approval.count
      }

      respond_to do |format|
        format.html { render 'show_community_admin' }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("stats_line",
              partial: "stats_line",
              locals: { messages: @messages, time_filter: @time_filter }
            ),
            turbo_stream.update("messages_table",
              partial: "messages_approval_table",
              locals: { messages: @messages, time_filter: @time_filter }
            )
          ]
        end
      end
    end

    def show_community_user_dashboard
      # Future implementation for community users
      render 'show_community_user'
    end

    private

    def get_filtered_messages(time_filter)
      case time_filter
      when 'one_week'
        Hke::FutureMessage.where(send_date: Date.current..1.week.from_now).order(:send_date)
      when 'two_weeks'
        Hke::FutureMessage.where(send_date: Date.current..2.weeks.from_now).order(:send_date)
      when 'one_month'
        Hke::FutureMessage.where(send_date: Date.current..1.month.from_now).order(:send_date)
      else
        Hke::FutureMessage.order(:send_date)
      end
    end
  end
end
