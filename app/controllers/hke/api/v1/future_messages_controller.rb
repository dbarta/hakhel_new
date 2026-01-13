class Hke::Api::V1::FutureMessagesController < Hke::Api::BaseController
  include Hke::SetCommunityAsTenant
  before_action :set_future_message, only: %i[show update destroy blast]

  # GET /future_messages
  def index
    name = params[:name]
    start_date = params[:start_date]
    end_date = params[:end_date]

    @future_messages = policy_scope(Hke::FutureMessage)
      .filter_by_name(name)
      .filter_by_date_range(start_date, end_date)

    render json: @future_messages, include: include_all?
  end

  # POST /api/v1/future_messages/123/blast
  def blast
    authorize @future_message, :blast?
    if @future_message.blast
      render json: @future_message, status: :ok, location: @future_message
    else
      render json: @future_message.errors, status: :unprocessable_entity
    end
  end


  # GET /future_messages/1
  def show
    render json: @future_message, include: include_all?
  end

  def create
    @future_message = Hke::FutureMessage.new(future_message_params)
    if @future_message.save
      render json: @future_message, status: :created, location: @future_message
    else
      render json: @future_message.errors, status: :unprocessable_entity
    end
  end

  def update
    params = future_message_params
    if @future_message.update(params)
      render json: @future_message, status: :ok
    else
      render json: @future_message.errors, status: :unprocessable_entity
    end
  end

  # DELETE /future_messages/1
  def destroy
    @future_message.destroy!
  end

  private

  def include_all?
    params.include?(:include_all) ? {address: nil} : nil
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_future_message
    @future_message = Hke::FutureMessage.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def future_message_params
    params.require(:future_message).permit(:send_date, :full_message, :message_type, :delivery_method, :email, :phone, :messageable_type, :messageable_id)
  end
end
