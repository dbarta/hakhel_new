class Hke::Api::V1::CommunitiesController < Hke::Api::BaseController
  # include Hke::SetCommunityAsTenant
  before_action :set_community, only: %i[show update destroy]

  # GET /communities
  def index
    @communities = policy_scope(Hke::Community)
    render json: @communities, include: include_all?
  end

  # GET /communities/1
  def show
    authorize @community
    render json: @community, include: include_all?
  end

  def create
    @community = Hke::Community.new(community_params)
    authorize @community
    if @community.save
      render json: @community, status: :created
    else
      render json: @community.errors, status: :unprocessable_entity
    end
  end

  def update
    authorize @community
    params = community_params
    if @community.update(params)
      render json: @community, include: :address, status: :ok
    else
      render json: @community.errors, status: :unprocessable_entity
    end
  end

  # DELETE /communities/1
  def destroy
    authorize @community
    @community.destroy!
  end

  private

  def include_all?
    params.include?(:include_all) ? {address: nil} : nil
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_community
    @community = Hke::Community.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def community_params
    params.require(:community).permit(:name, :description, :community_type, :account_id,
      address_attributes: [:id, :addressable_type, :address_type,
        :line1, :line2, :city, :state, :country, :postal_code, :_destroy])
  end

  def update_or_create_address(addressable, input_address)
    if addressable.address.present?
      addressable.address.update(input_address)
    else
      addressable.create_address(input_address.merge(address_type: "billing", addressable_type: "Hke::Community"))
    end
  end
end
