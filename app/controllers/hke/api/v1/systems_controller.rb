class Hke::Api::V1::SystemsController < Hke::Api::BaseController
  before_action :set_system, except: :create

  # Override Pundit callbacks since this controller doesn't have an index action
  skip_after_action :verify_authorized, except: [:index]
  skip_after_action :verify_policy_scoped
  after_action :verify_authorized, only: [:show, :create, :edit, :update]

  # GET /api/system
  def show
    authorize @system
    render json: @system, status: :ok
  end

  # POST /api/system
  def create
    @system = Hke::System.new(system_params)
    authorize @system
    if @system.save
      render json: @system, status: :created
    else
      render json: { errors: @system.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/system/edit
  def edit
    render json: @system, status: :ok
  end

  # PATCH /api/system
  def update
    if @system.update(system_params)
      render json: @system, status: :ok
    else
      render json: { errors: @system.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_system
    @system = Hke::System.first_or_initialize
  end

  def system_params
    params.require(:system).permit(:product_name, :version)
  end
end
