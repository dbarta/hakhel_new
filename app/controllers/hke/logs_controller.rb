require "pagy"
module Hke
  class LogsController < ApplicationController
    include Hke::SetCommunityAsTenant
    helper Hke::ApplicationHelper
    include Pagy::Backend
    include Pundit::Authorization

    def index
      authorize Hke::Log
      @event_types = Hke::Log.distinct.pluck(:event_type).compact.sort

      scope = policy_scope(Hke::Log)

      if params[:event_type].present?
        scope = scope.where(event_type: params[:event_type])
      end

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

      # scope = Hke::Log.all
      @pagy, @logs = pagy(scope, items: 100)
      # @logs = Hke::Log.all
      @logs.load
      puts "@@@@@@@@@ log count: #{@logs.count}"

      # respond_to do |format|
      #   format.html
      #   format.json { render json: @logs }
      # end
    end
  end
end
