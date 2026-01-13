module Hke
  class SmsMessagesController < ApplicationController
    before_action :set_community_as_current_tenant
    before_action :set_sms_message, only: [:show, :edit, :update, :destroy]

    # Uncomment to enforce Pundit authorization
    # after_action :verify_authorized
    # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    # GET /sms_messages
    def index
      @pagy, @sms_messages = pagy(SmsMessage.sort_by_params(params[:sort], sort_direction))

      # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
      # Calling @sms_messages.any? in the view will use the loaded records to check existence instead of making an extra DB call.
      @sms_messages.load

      # Uncomment to authorize with Pundit
      # authorize @sms_messages
    end

    # GET /sms_messages/1 or /sms_messages/1.json
    def show
    end

    # GET /sms_messages/new
    def new
      @sms_message = SmsMessage.new

      # Uncomment to authorize with Pundit
      # authorize @sms_message
    end

    # GET /sms_messages/1/edit
    def edit
    end

    # POST /sms_messages or /sms_messages.json
    def create
      @sms_message = SmsMessage.new(sms_message_params)
      @sms_message.user = current_user

      # Uncomment to authorize with Pundit
      # authorize @sms_message

      respond_to do |format|
        if @sms_message.save
          format.html { redirect_to @sms_message, notice: "Sms message was successfully created." }
          format.json { render :show, status: :created, location: @sms_message }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @sms_message.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /sms_messages/1 or /sms_messages/1.json
    def update
      respond_to do |format|
        if @sms_message.update(sms_message_params)
          format.html { redirect_to @sms_message, notice: "Sms message was successfully updated." }
          format.json { render :show, status: :ok, location: @sms_message }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @sms_message.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /sms_messages/1 or /sms_messages/1.json
    def destroy
      @sms_message.destroy
      respond_to do |format|
        format.html { redirect_to sms_messages_url, notice: "Sms message was successfully destroyed." }
        format.json { head :no_content }
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_sms_message
      @sms_message = SmsMessage.find(params[:id])

      # Uncomment to authorize with Pundit
      # authorize @sms_message
    end

    # Only allow a list of trusted parameters through.
    def sms_message_params
      params.require(:sms_message).permit(:name, :body, :user_id)

      # Uncomment to use Pundit permitted attributes
      # params.require(:sms_message).permit(policy(@sms_message).permitted_attributes)
    end
  end
end