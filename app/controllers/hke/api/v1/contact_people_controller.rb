class Hke::Api::V1::ContactPeopleController < Hke::Api::BaseController
  include Hke::SetCommunityAsTenant
  before_action :set_contact_person, only: %i[show update destroy]

  # GET /hke/contact_people
  def index
    @contact_people = policy_scope(Hke::ContactPerson)
    render json: @contact_people, include: include_all?
  end

  # GET /hke/contact_people/1
  def show
    authorize @contact_person
    render json: @contact_person, include: include_all?
  end

  # POST /hke/contact_people
  def create
    @contact_person = Hke::ContactPerson.new(contact_person_params)
    authorize @contact_person
    if @contact_person.save
      render json: @contact_person, methods: [:dedup_status], include: include_all?, status: :created, location: @contact_person
    else
      render json: @contact_person.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /hke/contact_people/1
  def update
    authorize @contact_person
    params = contact_person_params
    if @contact_person.update(params)
      render json: @contact_person, include: include_all?, status: :ok
    else
      render json: @contact_person.errors, status: :unprocessable_entity
    end
  end

  # DELETE /hke/contact_people/1
  def destroy
    authorize @contact_person
    @contact_person.destroy!
  end

  private

  def include_all?
    params.include?(:include_all) ? {address: nil, relations: {include: :deceased_person}} : nil
  end

  def set_contact_person
    @contact_person = Hke::ContactPerson.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def contact_person_params
    params.require(:contact_person).permit(
      :first_name, :last_name, :email, :phone, :gender,
      relations_attributes: [
        :id, :relation_of_deceased_to_contact, :_destroy,
        deceased_person_attributes: [
          :id, :first_name, :last_name,
          :gender, :father_first_name, :mother_first_name,
          :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death,
          :time_of_death, :location_of_death, :cemetery_id, :cemetery_region, :cemetery_parcel, :_destroy
        ]
      ],
      address_attributes: [
        :id, :addressable_type, :address_type, :line1, :line2, :city,
        :state, :country, :postal_code, :_destroy
      ]
    )
  end
end
