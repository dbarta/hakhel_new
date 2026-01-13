module Hke
  class FutureMessagesController < ApplicationController
    # before_action :authenticate_user!
    before_action :set_community_as_current_tenant
    before_action :authenticate_user!
    before_action :authorize_community_admin!
    before_action :set_future_message, only: [:show, :destroy, :blast]

    # GET /future_messages index
    # POST /future_messages search
    def index
  @future_messages = FutureMessage.order(:send_date)
      if params[:name_search]
        key = "%#{params[:name_search]}%"
        @future_messages = @future_messages.where("first_name ILIKE ?", key)
          .or(@future_messages.where("last_name ILIKE ?", key))
      end
      @future_messages = @future_messages.sort_by_params(params[:sort], sort_direction)
      @future_messages.load

      respond_to do |format|
        format.html # Response for normal get - show full index
        format.turbo_stream do # Response from post, which is result of input from the search box
          render turbo_stream: [
            turbo_stream.update(
              "search_results",
              partial: "hke/shared/search_results",
              locals: {
                items: @future_messages,
                fields: [:send_date, :full_message, :message_type, :delivery_method, :email, :phone, :token],
                other_fields: [
                  { header: t('hebrew_year_of_death'), data: :hebrew_year_of_death },
                  { header: t('hebrew_month_of_death'), data: :hebrew_month_of_death },
                  { header: t('hebrew_day_of_death'), data: :hebrew_day_of_death }
                ],
                actions: [
                  { name: "send_individual_message", path: :blast_future_message_path, method: :post }
                ]
              }
            ),
            turbo_stream.update("people_count", @future_messages.count)
          ]
        end
      end
    end

    # POST /api/v1/future_messages/123/blast
    def blast
      if @future_message.blast
        respond_to do |format|
          format.html { redirect_to future_messages_url, notice: "Future Message was successfully sent." }
         # format.json { status: :ok, location: @future_message }
        end
        # render json: @future_message, status: :ok, location: @future_message
      else
        render json: @future_message.errors, status: :unprocessable_entity
      end
    end

    # GET /future_messages/1 or /future_messages/1.json
    def show
    end

    # DELETE /deceased_people/1 or /deceased_people/1.json
    def destroy
      @future_message.destroy
      respond_to do |format|
        format.turbo_stream { redirect_to future_messages_url, notice: "Future Message was successfully destroyed.", status: :see_other }
        format.html { redirect_to future_messages_url, notice: "Future Message was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      end
    end

    # GET /future_messages/approve
    def approve
      @messages = Hke::FutureMessage.pending_approval.includes(:messageable, :approved_by).order(:send_date)
      render 'approve'
    end

    # POST /future_messages/:id/toggle_approval
    def toggle_approval
      @message = Hke::FutureMessage.find(params[:id])
      authorize @message, :approve?

      if @message.approved?
        @message.reset_approval!
      else
        @message.approve!(current_user)
      end

      @time_filter = params[:time_filter] || 'one_week'
      @messages = get_filtered_messages(@time_filter)

      respond_to do |format|
        format.turbo_stream { render :toggle_approval }
        format.html { redirect_back(fallback_location: root_path) }
      end
    end

    # POST /future_messages/approve_all
    def approve_all
      authorize Hke::FutureMessage, :bulk_approve?

      time_filter = params[:time_filter] || 'one_week'
      messages_to_update = get_filtered_messages(time_filter).pending_approval

      messages_to_update.each { |message| message.approve!(current_user) }

      redirect_back(fallback_location: root_path)
    end

    # POST /future_messages/disapprove_all
    def disapprove_all
      authorize Hke::FutureMessage, :bulk_approve?

      time_filter = params[:time_filter] || 'one_week'
      messages_to_update = get_filtered_messages(time_filter).approved_messages

      messages_to_update.each(&:reset_approval!)

      redirect_back(fallback_location: root_path)
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_future_message
      @future_message = FutureMessage.find(params[:id])
    end

    def authorize_community_admin!
      unless current_user.community_admin? || current_user.system_admin?
        redirect_to root_path, alert: t('unauthorized')
      end
    end

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
