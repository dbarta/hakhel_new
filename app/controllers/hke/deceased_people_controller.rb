module Hke
  class DeceasedPeopleController < ApplicationController
    before_action :authenticate_user!
    before_action :set_community_as_current_tenant
    before_action :set_deceased_person, only: [:show, :edit, :update, :destroy]

    # GET /deceased_people index
    # POST /deceased_people search
    def index
      @deceased_people = policy_scope(DeceasedPerson).includes(relations: [:contact_person])
      if params[:name_search]
        key = "%#{params[:name_search]}%"
        @deceased_people = @deceased_people.where("first_name ILIKE ?", key)
          .or(@deceased_people.where("last_name ILIKE ?", key))
      end
      @deceased_people = @deceased_people.sort_by_params(params[:sort], sort_direction)
      @deceased_people.load

      respond_to do |format|
        format.html # Response for normal get - show full index
        format.turbo_stream do # Response from post, which is result of input from the search box
          render turbo_stream: [
            turbo_stream.update(
              "search_results",
              partial: "hke/shared/search_results",
              locals: {
                items: @deceased_people,
                fields: [:first_name, :last_name, :father_first_name, :mother_first_name,
                         :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death,
                         :date_of_death, :gender],
                other_fields: [{ header: t('contact_people'), data: "contact_name" }],
                actions: [
                  { name: "action_edit", path: :edit_deceased_person_path },
                  { name: "action_delete", path: :deceased_person_path, method: :delete, confirm: true }
                ]
              }
            ),
            turbo_stream.update("people_count", @deceased_people.count)
          ]
        end
      end
    end

    # GET /deceased_people/1 or /deceased_people/1.json
    def show
      authorize @deceased_person
      @contacts = @deceased_person.contact_people
    end

    # GET /deceased_people/new
    def new
      @deceased_person = DeceasedPerson.new
      authorize @deceased_person
      @deceased_person.relations.build.build_contact_person
    end

    # GET /deceased_people/1/edit
    def edit
      authorize @deceased_person
    end

    # POST /deceased_people or /deceased_people.json
    def create
      @deceased_person = DeceasedPerson.new(deceased_person_params)
      authorize @deceased_person

      respond_to do |format|
        if @deceased_person.save
          format.html { redirect_to @deceased_person, notice: "Deceased person was successfully created." }
          format.json { render :show, status: :created, location: @deceased_person }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @deceased_person.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /deceased_people/1 or /deceased_people/1.json
    def update
      authorize @deceased_person
      remove_empty_relations_from "deceased_person", "contact_person"
      respond_to do |format|
        if @deceased_person.update(deceased_person_params)
          format.html { redirect_to @deceased_person, notice: "Deceased person was successfully updated." }
          format.json { render :show, status: :ok, location: @deceased_person }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @deceased_person.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /deceased_people/1 or /deceased_people/1.json
    def destroy
      authorize @deceased_person
      @deceased_person.destroy
      respond_to do |format|
        format.turbo_stream { redirect_to deceased_people_url, notice: "Deceased person was successfully destroyed.", status: :see_other }
        format.html { redirect_to deceased_people_url, notice: "Deceased person was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_deceased_person
      @deceased_person = DeceasedPerson.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def deceased_person_params
      params.require(:deceased_person).permit(:first_name, :last_name, :gender, :occupation,
        :organization, :religion, :father_first_name, :mother_first_name,
        :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death,
        :date_of_death, :time_of_death, :location_of_death,
        relations_attributes: [:id, :relation_of_deceased_to_contact, :_destroy,
          contact_person_attributes: [:id, :first_name, :last_name, :email, :phone, :_destroy]])
      # params.require(:person).permit(:name, :birth_date, relationships_attributes: [:id, :relationship_type, :_destroy, contact_attributes: [:id, :name, :location, :_destroy]] )
    end
  end
end
