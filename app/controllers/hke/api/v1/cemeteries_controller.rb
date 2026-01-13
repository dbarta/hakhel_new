class Hke::Api::V1::CemeteriesController < Api::BaseController
  include Hke::SetCommunityAsTenant

  before_action :set_cemetery, only: %i[show update destroy]

  # GET /cemeteries
  def index
    @cemeteries = Hke::Cemetery.all
    render json: @cemeteries, include: include_all?
  end

  # GET /cemeteries/1
  def show
    render json: @cemetery, include: include_all?
  end

  def create
    @cemetery = Hke::Cemetery.new(cemetery_params)
    if @cemetery.save
      render json: @cemetery, include: :address, status: :created, location: @cemetery
    else
      render json: @cemetery.errors, status: :unprocessable_entity
    end
  end

  def update
    params = cemetery_params
    if @cemetery.update(params)
      render json: @cemetery, include: :address, status: :ok
    else
      render json: @cemetery.errors, status: :unprocessable_entity
    end
  end

  # DELETE /cemeteries/1
  def destroy
    @cemetery.destroy!
  end

  private

  def include_all?
    params.include?(:include_all) ? {address: nil} : nil
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_cemetery
    @cemetery = Hke::Cemetery.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def cemetery_params
    params.require(:cemetery).permit(:name, :description,
      address_attributes: [:id, :addressable_type, :address_type,
        :line1, :line2, :city, :state, :country, :postal_code, :_destroy])
  end

  def update_or_create_address(addressable, input_address)
    if addressable.address.present?
      addressable.address.update(input_address)
    else
      addressable.create_address(input_address.merge(address_type: "billing", addressable_type: "Hke::Cemetery"))
    end
  end
end
