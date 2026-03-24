module Hke
  class LandingPagesController < ApplicationController
    before_action :set_community_as_current_tenant
    layout "hke/landing", only: :show
    include Hke::ApplicationHelper
    include Hke::MessageGenerator

    skip_after_action :verify_authorized, only: [:show, :sms_preview]
    skip_after_action :verify_policy_scoped, only: [:show, :sms_preview]

    # GET /landing_pages
    def index

    end

    HEBREW_DAYS = { 0 => "ראשון", 1 => "שני", 2 => "שלישי", 3 => "רביעי", 4 => "חמישי", 5 => "שישי", 6 => "שבת" }.freeze

    def sms_preview
      @token = params[:token]
      if @token
        relation = Relation.find_by_token(@token)
        if relation
          d = relation.deceased_person
          contact = relation.contact_person
          yahrzeit_date = Hke::Heb.yahrzeit_date(d.name, d.hebrew_month_of_death, d.hebrew_day_of_death)
          @send_date = yahrzeit_date - 1.week
          @yahrzeit_date = yahrzeit_date
          @yahrzeit_hebrew = "#{d.hebrew_day_of_death} #{d.hebrew_month_of_death}"
          @yahrzeit_day_of_week = HEBREW_DAYS[yahrzeit_date.wday]
          send_heb = Hke::Heb.g2h(d.name, @send_date)
          if send_heb
            heb_month = Hke::Heb.english_month_to_hebrew(send_heb['hm'].to_sym) || send_heb['hm']
            @send_date_hebrew = "#{send_heb['hd']} #{heb_month}"
          end
          @send_date_day_of_week = HEBREW_DAYS[@send_date.wday]
          short_link = Hke::ShortLink.find_or_create_by!(contact_person: contact, via_token: nil)
          snippets = generate_hebrew_snippets(relation, [:sms], reference_date: @send_date, portal_url: short_link.short_url)
          @sms_text = snippets[:sms]
          @contact_name = contact&.name
          @deceased_name = d.name
        end
      end
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
	          format.html { redirect_to hke_landing_page_path(@landing_page), notice: "Landing page was successfully created." }
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
	          format.html { redirect_to hke_landing_page_path(@landing_page), notice: "Landing page was successfully updated." }
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
	        format.html { redirect_to hke_landing_pages_path, notice: "Landing page was successfully destroyed." }
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
      params.require(:hke_landing_page).permit(:name, :body, :user_id)

      # Uncomment to use Pundit permitted attributes
      # params.require(:landing_page).permit(policy(@landing_page).permitted_attributes)
    end
  end
end
