class Hke::Api::V1::DeceasedPeopleController < Hke::Api::BaseController
  include Hke::SetCommunityAsTenant
  before_action :set_hke_deceased_person, only: %i[show update destroy]

  # GET /hke/deceased_people
  def index
    @hke_deceased_people = policy_scope(Hke::DeceasedPerson)
    render json: @hke_deceased_people, include: include_all?
  end

  # GET /hke/deceased_people/1
  def show
    authorize @hke_deceased_person
    render json: @hke_deceased_person, include: {relations: {include: {contact_person: {include: :address}}}}
  end

  # POST /hke/deceased_people
  def create
    @hke_deceased_person = Hke::DeceasedPerson.new(deceased_person_params)
    authorize @hke_deceased_person
    if @hke_deceased_person.save
      render json: @hke_deceased_person, methods: [:dedup_status], include: {relations: {include: {contact_person: {include: :address}}}}, status: :created
    else
      render json: @hke_deceased_person.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /hke/deceased_people/1
  def update
    authorize @hke_deceased_person
    if @hke_deceased_person.update(deceased_person_params)
      render json: @hke_deceased_person, include: {relations: {include: {contact_person: {include: :address}}}}
    else
      render json: @hke_deceased_person.errors, status: :unprocessable_entity
    end
  end

  # DELETE /hke/deceased_people/1
  def destroy
    authorize @hke_deceased_person
    @hke_deceased_person.destroy!
  end

  private

  def include_all?
    params.include?(:include_all) ? {relations: {include: {contact_person: {include: :address}}}} : nil
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_hke_deceased_person
    @hke_deceased_person = Hke::DeceasedPerson.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def deceased_person_params
    params.require(:deceased_person).permit(
      :id, :first_name, :last_name,
      :gender, :father_first_name, :mother_first_name,
      :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death,
      :time_of_death, :location_of_death, :cemetery_id, :cemetery_region, :cemetery_parcel,
      relations_attributes: [
        :id, :relation_of_deceased_to_contact, :_destroy,
        contact_person_attributes: [
          :id, :first_name, :last_name, :phone, :email, :gender, :_destroy,
          address_attributes: [
            :id, :addressable_type, :address_type, :line1, :line2, :city,
            :state, :country, :postal_code, :_destroy
          ]
        ]
      ]
    )
  end
end
