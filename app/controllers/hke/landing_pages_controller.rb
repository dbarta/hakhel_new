module Hke
  class LandingPagesController < ApplicationController
    before_action :set_community_as_current_tenant
    layout "hke/landing", only: :show
    include Hke::ApplicationHelper
    include Hke::MessageGenerator

    # Uncomment to enforce Pundit authorization
    # after_action :verify_authorized
    # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    # GET /landing_pages
    def index

    end

    # GET /landing_pages/1 or /landing_pages/1.json
    def show
      Hke::heb_debug = true
      @token = params['token']
      if @token
        relation = Relation.find_by_token(@token)
        if relation
          d = relation.deceased_person
          yahrzeit_date = Hke::Heb.yahrzeit_date(d.name, d.hebrew_month_of_death, d.hebrew_day_of_death)
          send_date = (yahrzeit_date - 1.week)
          send_date = Date.today if send_date < Date.today
          snippets = generate_hebrew_snippets(relation, reference_date: send_date)
          @sms_preview = snippets[:sms]
          @landing_page_preview = snippets[:web]
        end
      end
    end

    # GET /landing_pages/new
    def new
      @landing_page = LandingPage.new

      # Uncomment to authorize with Pundit
      # authorize @landing_page
    end

    # GET /landing_pages/1/edit
    def edit
    end

    # POST /landing_pages or /landing_pages.json
    def create
      @landing_page = LandingPage.new(landing_page_params)
      @landing_page.user = current_user

      # Uncomment to authorize with Pundit
      # authorize @landing_page

      respond_to do |format|
        if @landing_page.save
          format.html { redirect_to @landing_page, notice: "Landing page was successfully created." }
          format.json { render :show, status: :created, location: @landing_page }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @landing_page.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /landing_pages/1 or /landing_pages/1.json
    def update
      respond_to do |format|
        if @landing_page.update(landing_page_params)
          format.html { redirect_to @landing_page, notice: "Landing page was successfully updated." }
          format.json { render :show, status: :ok, location: @landing_page }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @landing_page.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /landing_pages/1 or /landing_pages/1.json
    def destroy
      @landing_page.destroy
      respond_to do |format|
        format.html { redirect_to landing_pages_url, notice: "Landing page was successfully destroyed." }
        format.json { head :no_content }
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_landing_page
      @landing_page = LandingPage.find(params[:id])

      # Uncomment to authorize with Pundit
      # authorize @landing_page
    end

    # Only allow a list of trusted parameters through.
    def landing_page_params
      params.require(:landing_page).permit(:name, :body, :user_id)

      # Uncomment to use Pundit permitted attributes
      # params.require(:landing_page).permit(policy(@landing_page).permitted_attributes)
    end
  end
end
