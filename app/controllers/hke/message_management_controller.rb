module Hke
  class MessageManagementController < ApplicationController
    include Hke::SetCommunityAsTenant
    before_action :authenticate_user!
    before_action :authorize_community_admin!

    def index
      authorize [:hke, :message_management], :index?
      @time_filter = params[:time_filter] || 'last_30_days'
      @status_filter = params[:status_filter] || 'all'

      # Get date range based on filter
      date_range = case @time_filter
                   when 'last_7_days'
                     7.days.ago..Time.current
                   when 'last_30_days'
                     30.days.ago..Time.current
                   when 'last_90_days'
                     90.days.ago..Time.current
                   when 'this_year'
                     Date.current.beginning_of_year..Time.current
                   else
                     30.days.ago..Time.current
                   end

      # Base query for sent messages with existing structure
      @sent_messages = if defined?(Hke::SentMessage)
                         policy_scope(Hke::SentMessage).where(created_at: date_range)
                                        .order(created_at: :desc)
                                        .limit(100)
                       else
                         []
                       end

      # Statistics
      calculate_statistics(date_range)

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("messages_table",
            partial: "messages_table",
            locals: { messages: @sent_messages })
        end
      end
    end

    def show
      @sent_message = Hke::SentMessage.find(params[:id]) if defined?(Hke::SentMessage)
      authorize @sent_message if @sent_message
    end

    private

    def calculate_statistics(date_range)
      if defined?(Hke::SentMessage)
        all_messages = Hke::SentMessage.where(created_at: date_range)

        @stats = {
          total_sent: all_messages.count, # For now, assume all are sent
          total_failed: 0, # Will implement when we have proper status tracking
          total_messages: all_messages.count,
          success_rate: all_messages.count > 0 ? 100 : 0, # Assume 100% for now
          most_common_errors: [] # Will implement when we have error tracking
        }
      else
        @stats = {
          total_sent: 0,
          total_failed: 0,
          total_messages: 0,
          success_rate: 0,
          most_common_errors: []
        }
      end

      # Future messages statistics
      @future_stats = {
        pending_approval: Hke::FutureMessage.pending_approval.count,
        approved_upcoming: Hke::FutureMessage.approved_messages.where('send_date > ?', Time.current).count,
        total_scheduled: Hke::FutureMessage.where('send_date > ?', Time.current).count
      }
    end

    def calculate_success_rate(messages)
      return 0 if messages.count.zero?
      sent_count = messages.where(status: 'sent').count
      (sent_count.to_f / messages.count * 100).round(2)
    end

    def get_common_errors(failed_messages)
      return [] unless failed_messages.respond_to?(:group)

      failed_messages.group(:error_message)
                    .count
                    .sort_by { |_, count| -count }
                    .first(5)
                    .map { |error, count| { error: error, count: count } }
    end

    def authorize_community_admin!
      unless current_user.community_admin? || current_user.system_admin?
        redirect_to hke.root_path, alert: t('admin.dashboard.access_denied')
      end
    end
  end
end
