module Hke
  class ContactPeopleController < ApplicationController
    # before_action :authenticate_user!
    before_action :set_community_as_current_tenant
    before_action :authenticate_admin
    before_action :set_contact_person, only: [:show, :edit, :update, :destroy]

    # GET /contact_people index
    # POST /contact_people search
    def index
      @contact_people = policy_scope(ContactPerson).includes(relations: [:deceased_person])
      if params[:name_search]
        key = "%#{params[:name_search]}%"
        @contact_people = @contact_people.where("first_name ILIKE ?", key)
          .or(@contact_people.where("last_name ILIKE ?", key))
      end
      @contact_people = @contact_people.sort_by_params(params[:sort], sort_direction)
      @contact_people.load

      respond_to do |format|
        format.html # Response for normal get - show full index
        format.turbo_stream do # Response from post, which is result of input from the search box
          render turbo_stream: [
            turbo_stream.update(
              "search_results",
              partial: "hke/shared/search_results",
              locals: {
                items: @contact_people,
                fields: [:first_name, :last_name, :email, :phone, :gender],
                other_fields: [],
                actions: [
                  { name: "action_edit", path: :edit_contact_person_path },
                  { name: "action_delete", path: :contact_person_path, method: :delete, confirm: true }
                ]
              }
            ),
            turbo_stream.update("people_count", @contact_people.count)
          ]
        end
      end
    end

    # GET /contact_people/1 or /contact_people/1.json
    def show
      authorize @contact_person
      @contact_people = @contact_person.deceased_people
    end

    # GET /contact_people/new
    def new
      @contact_person = ContactPerson.new
      authorize @contact_person
      @contact_person.relations.build.build_deceased_person
    end

    # GET /contact_people/1/edit
    def edit
      authorize @contact_person
    end

    # POST /contact_people or /contact_people.json
    def create
      @contact_person = ContactPerson.new(contact_person_params)
      authorize @contact_person

      respond_to do |format|
        if @contact_person.save
          format.html { redirect_to @contact_person, notice: "Contact person was successfully created." }
          format.json { render :show, status: :created, location: @contact_person }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @contact_person.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /contact_people/1 or /contact_people/1.json
    def update
      authorize @contact_person
      remove_empty_relations_from "contact_person", "deceased_person"
      respond_to do |format|
        if @contact_person.update(contact_person_params)
          format.html { redirect_to @contact_person, notice: "Contact person was successfully updated." }
          format.json { render :show, status: :ok, location: @contact_person }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @contact_person.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /contact_people/1 or /contact_people/1.json
    def destroy
      authorize @contact_person
      @contact_person.destroy
      respond_to do |format|
        format.turbo_stream { redirect_to contact_people_url, notice: "Contact person was successfully destroyed.", status: :see_other }
        format.html { redirect_to contact_people_url, notice: "Contact person was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_contact_person
      @contact_person = ContactPerson.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def contact_person_params
      params.require(:contact_person).permit(:first_name, :last_name, :email, :phone, :gender,
        relations_attributes: [:id, :relation_of_deceased_to_contact, :_destroy,
          deceased_person_attributes: [:id, :first_name, :last_name, :gender, :occupation,
            :organization, :religion, :father_first_name, :mother_first_name,
            :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death,
            :date_of_death, :time_of_death, :location_of_death]])
    end
  end
end
