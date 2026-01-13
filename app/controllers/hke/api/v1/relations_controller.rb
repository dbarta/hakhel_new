class Hke::Api::V1::RelationsController < Api::BaseController
  include Hke::SetCommunityAsTenant
  before_action :set_relation, only: %i[ show update destroy ]

  # GET /hke/relations
  def index
    @relations = Hke::Relation.all
    render json: @relations
  end

  # GET /hke/relations/1
  def show
    render json: {
          relation: @relation,
          deceased_person: @relation.deceased_person,
          contact_person: @relation.contact_person
      }
  end

  # POST /hke/relations
  def create
    @relation = Hke::Relation.new(relation_params)

    if @relation.save
      render json: @relation, methods: [:dedup_status]
    else
      render json: @relation.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /hke/relations/1
  def update
    params = relation_params

    if @relation.update(params)
      render json: @relation, status: :ok
    else
      render json: @relation.errors, status: :unprocessable_entity
    end
  end

  # DELETE /hke/relations/1
  def destroy
      @relation.destroy!
  end

  private

    def set_relation
      @relation = Hke::Relation.find(params[:id])
    end

    def relation_params
      params.require(:relation).permit(:deceased_person_id, :contact_person_id, :relation_of_deceased_to_contact, :community_id)
    end

end
