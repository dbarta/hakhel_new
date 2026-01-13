module Hke
  class SelectionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_community_as_current_tenant
    before_action :set_selection, only: [:show, :edit, :update, :destroy]

    # GET /selections
    # Show table of selections.
    def index
      @pagy, @selections = pagy(policy_scope(Selection).sort_by_params(params[:sort], sort_direction))
      @selections.load
    end

    # GET /selections/1 or /selections/1.json
    def show
      authorize @selection
    end

    # GET /selections/new
    # This shows a form to create a new selection, with name and puspose fields.
    # It shows a table of relations, where for each relation it shows:
    # name of deceased, name of contact, their relatiosnhip, and date of death in hebrew and gregorian (it can be in a sentence)
    # Each row will have a checkbox to select  or unselect it.
    # Above the table there will be an action bar which will have the following options:
    # - Select all rows
    # - Unselect all rows
    # - Show the table filtered by names (wild card) on both contact and deceased. This will not be autocomplete - you have to press <go>
    # - Show the table filtered by deceased person death date. This can have a few options:
    #   . Deceased with date this week (indication of who was already in the past)
    #   . Deceased with date next week
    #   . Deceased with date next month
    #   . Deceased with date not more than n days from today
    # - There is a save button
    def new
      @selection = Selection.new

      if params[:name_search]
        # If there is a keyword seach, do it and present selections
        key = params[:name_search]
        ds_ids = select_by_name DeceasedPerson, key
        cs_ids = select_by_name ContactPerson, key
        candidate_relations = Relation.includes(:deceased_person, :contact_person)
              .where(deceased_person_id: ds_ids, contact_person_id: cs_ids )
      else
        # Just pick any 20
        candidate_relations = Relation.includes(:deceased_person, :contact_person).limit(20)
      end

      candidate_relations.load
      # internal adhoc struct just to present one selection in the GUI
      row = Struct.new(:sentence, :relation_id, :is_selected)

      # This will be show in the selection table
      @rows = candidate_relations.map{|relation| row.new(sentence(relation), relation.id, false)}


      respond_to do |format|
        format.html # Response for normal get - show full index
        format.turbo_stream do #Response from post, which is result of input from the search box
          render turbo_stream: [
            turbo_stream.update( "search_results", partial: "search_results", locals: {items: @contact_people}),
            turbo_stream.update( "people_count", @contact_people.count)
          ]
        end
      end
    end

    # GET /selections/1/edit
    def edit
    end

    # POST /selections or /selections.json
    def create
      @selection = Selection.new(selection_params)

      # Uncomment to authorize with Pundit
      # authorize @selection

      respond_to do |format|
        if @selection.save
          format.html { redirect_to @selection, notice: "Selection was successfully created." }
          format.json { render :show, status: :created, location: @selection }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @selection.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /selections/1 or /selections/1.json
    def update
      respond_to do |format|
        if @selection.update(selection_params)
          format.html { redirect_to @selection, notice: "Selection was successfully updated." }
          format.json { render :show, status: :ok, location: @selection }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @selection.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /selections/1 or /selections/1.json
    def destroy
      @selection.destroy
      respond_to do |format|
        format.html { redirect_to selections_url, notice: "Selection was successfully destroyed." }
        format.json { head :no_content }
      end
    end

    private

    # Creates a readable sentence with information about selected deceased and contact
    def sentence relation
      # "רבקה אפשטיין פטירה: י״ג תשרי תשס״ג 21.4.2008 איש קשר (בן): חנן אפשטיין (עוד 7 ימים)"
      d = relation.deceased_person
      deceased_name = d.name
      contact_name = relation.contact_person.name
      hebrew_date = "#{d.hebrew_year_of_death} #{d.hebrew_month_of_death} #{d.hebrew_day_of_death}"
      gregorian_date = d.date_of_death
      reltype = I18n.t(relation.relation_of_deceased_to_contact)
      num_days = 7
      "מר "+ deceased_name + ", תאריך פטירה " + hebrew_date + ", איש קשר: " +  contact_name  + "  (" + reltype + ") עוד " + num_days.to_s + " ימים"

    end

    # Use callbacks to share common setup or constraints between actions.
    def set_selection
      @selection = Selection.find(params[:id])

      # Uncomment to authorize with Pundit
      # authorize @selection
    end

    # Only allow a list of trusted parameters through.
    def selection_params
      params.require(:selection).permit(:name, :purpose)

      # Uncomment to use Pundit permitted attributes
      # params.require(:selection).permit(policy(@selection).permitted_attributes)
    end
  end
end