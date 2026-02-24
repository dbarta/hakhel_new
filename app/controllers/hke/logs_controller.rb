require "pagy"
module Hke
  class LogsController < ApplicationController
    include Hke::SetCommunityAsTenant
    helper Hke::ApplicationHelper
    include Pagy::Backend
    include Pundit::Authorization

    def index
      authorize Hke::Log

      all_logs = policy_scope(Hke::Log)
      @total_count = all_logs.count
      @earliest_date = all_logs.minimum(:event_time)&.to_date

      # Distinct values for filter dropdowns
      @event_types = all_logs.distinct.pluck(:event_type).compact.sort
      @entity_types = all_logs.distinct.pluck(:entity_type).compact.sort

      scope = all_logs

      scope = scope.where(event_type: params[:event_type]) if params[:event_type].present?
      scope = scope.where(entity_type: params[:entity_type]) if params[:entity_type].present?

      begin
        start_date = Date.parse(params[:start]) if params[:start].present?
        end_date = Date.parse(params[:end]) if params[:end].present?
      rescue ArgumentError
        start_date = end_date = nil
      end

      if start_date && end_date
        scope = scope.where(event_time: start_date.beginning_of_day..end_date.end_of_day)
      elsif start_date
        scope = scope.where("event_time >= ?", start_date.beginning_of_day)
      elsif end_date
        scope = scope.where("event_time <= ?", end_date.end_of_day)
      end

      sort_column = %w[event_time event_type entity_type message_token ip_address error_type].include?(params[:sort]) ? params[:sort] : "event_time"
      sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"

      scope = scope.order("#{sort_column} #{sort_direction}")

      # Per-page: "all" or a number
      @per_page = params[:per_page]
      if @per_page == "all"
        items_count = scope.count.clamp(1, 999_999)
      else
        items_count = [50, 100, 250, 500].include?(@per_page.to_i) ? @per_page.to_i : 100
        @per_page = items_count.to_s
      end

      @pagy, @logs = pagy(scope, limit: items_count)

      @logs.load
    end

    def destroy_all
      authorize Hke::Log, :destroy_all?

      logs = policy_scope(Hke::Log)
      destroyed_count = logs.delete_all

      redirect_to hke_logs_path,
        notice: t("hke.logs.index.cleared", count: destroyed_count),
        status: :see_other
    end
  end
end
