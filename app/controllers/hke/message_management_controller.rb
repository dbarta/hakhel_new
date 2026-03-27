module Hke
  class MessageManagementController < ApplicationController
    include Hke::SetCommunityAsTenant
    before_action :authenticate_user!
    before_action :authorize_community_admin!

    def index
      authorize [:hke, :message_management], :index?
      @time_filter = params[:time_filter] || "last_30_days"
      @tab = params[:tab] || "sent"
      @status_filter = params[:status_filter] || "all"

      date_range = resolve_date_range(@time_filter)

      sent_scope = policy_scope(Hke::SentMessage).where(created_at: date_range)
      sent_scope = case @status_filter
      when "delivered" then sent_scope.where(delivery_status: "delivered")
      when "failed"    then sent_scope.where(delivery_status: Hke::SentMessage::FAILED_STATUSES)
      when "pending"   then sent_scope.where.not(delivery_status: ["delivered"] + Hke::SentMessage::FAILED_STATUSES)
      else sent_scope
      end

      @sent_messages = sent_scope.order(created_at: :desc).limit(100)

      @not_sent_messages = policy_scope(Hke::NotSentMessage)
        .where(created_at: date_range)
        .order(created_at: :desc)
        .limit(100)

      calculate_statistics(date_range)
      calculate_bounce_stats

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("messages_content",
            partial: "messages_content",
            locals: {
              sent_messages: @sent_messages,
              not_sent_messages: @not_sent_messages,
              tab: @tab,
              status_filter: @status_filter,
              time_filter: @time_filter
            })
        end
      end
    end

    def show
      @sent_message = Hke::SentMessage.find(params[:id])
      authorize @sent_message
    end

    def send_bounce_notifications
      authorize [:hke, :message_management], :index?
      contacts = policy_scope(Hke::ContactPerson).with_bounced_email_and_phone
      contacts.each do |contact|
        Hke::BounceNotificationSmsJob.perform_async(contact.id, current_community.id)
      end
      redirect_to hke_message_management_index_path,
        notice: t("hke.bounce_notifications.bulk_sent_notice", count: contacts.size)
    end

    private

    def resolve_date_range(filter)
      case filter
      when "last_7_days" then 7.days.ago..Time.current
      when "last_30_days" then 30.days.ago..Time.current
      when "last_90_days" then 90.days.ago..Time.current
      when "this_year" then Date.current.beginning_of_year..Time.current
      else 30.days.ago..Time.current
      end
    end

    def calculate_statistics(date_range)
      sent_count = policy_scope(Hke::SentMessage).where(created_at: date_range).count
      not_sent_count = policy_scope(Hke::NotSentMessage).where(created_at: date_range).count
      total = sent_count + not_sent_count

      delivered_count = policy_scope(Hke::SentMessage)
        .where(created_at: date_range, delivery_status: "delivered").count
      delivery_failure_count = policy_scope(Hke::SentMessage)
        .where(created_at: date_range, delivery_status: Hke::SentMessage::FAILED_STATUSES).count

      @stats = {
        total_sent: sent_count,
        total_failed: not_sent_count,
        total_messages: total,
        delivered_confirmed: delivered_count,
        delivery_failures: delivery_failure_count,
        success_rate: (total > 0) ? (delivered_count.to_f / total * 100).round(1) : 0,
        most_common_errors: get_common_errors(date_range)
      }

      @future_stats = {
        pending_approval: Hke::FutureMessage.pending_approval.count,
        approved_upcoming: Hke::FutureMessage.approved_messages.where("send_date > ?", Time.current).count,
        total_scheduled: Hke::FutureMessage.where("send_date > ?", Time.current).count
      }
    end

    def get_common_errors(date_range)
      policy_scope(Hke::NotSentMessage)
        .where(created_at: date_range)
        .group(:reason)
        .count
        .sort_by { |_, count| -count }
        .first(5)
        .map { |reason, count| {error: I18n.t("message_management.not_sent_reasons.#{reason}"), count: count} }
    end

    def calculate_bounce_stats
      bounced = policy_scope(Hke::ContactPerson).email_bounced
      @bounced_with_phone = bounced.where.not(phone: nil).count
      @bounced_no_phone   = bounced.where(phone: nil).count
    end

    def authorize_community_admin!
      unless current_user.community_admin? || current_user.system_admin?
        redirect_to hke_root_path, alert: t("admin.dashboard.access_denied")
      end
    end
  end
end
