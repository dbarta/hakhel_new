module Hke
  class CemeteriesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_community_as_current_tenant
    before_action :set_cemetery, only: [:show, :edit, :update, :destroy]

    # GET /cemeteries
    def index
      @pagy, @cemeteries = pagy(policy_scope(Cemetery).sort_by_params(params[:sort], sort_direction))

      # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
      # Calling @cemeteries.any? in the view will use the loaded records to check existence instead of making an extra DB call.
      @cemeteries.load
    end

    # GET /cemeteries/1 or /cemeteries/1.json
    def show
      authorize @cemetery
    end

    # GET /cemeteries/new
    def new
      @cemetery = Cemetery.new
      authorize @cemetery
    end

    # GET /cemeteries/1/edit
    def edit
      authorize @cemetery
    end

    # POST /cemeteries or /cemeteries.json
    def create
      @cemetery = Cemetery.new(cemetery_params)
      authorize @cemetery

      respond_to do |format|
        if @cemetery.save
          format.html { redirect_to @cemetery, notice: "Cemetery was successfully created." }
          format.json { render :show, status: :created, location: @cemetery }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @cemetery.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /cemeteries/1 or /cemeteries/1.json
    def update
      authorize @cemetery
      respond_to do |format|
        if @cemetery.update(cemetery_params)
          format.html { redirect_to @cemetery, notice: "Cemetery was successfully updated." }
          format.json { render :show, status: :ok, location: @cemetery }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @cemetery.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /cemeteries/1 or /cemeteries/1.json
    def destroy
      authorize @cemetery
      @cemetery.destroy
      respond_to do |format|
        format.turbo_stream { redirect_to cemeteries_url, notice: "Cemetery was successfully destroyed.", status: :see_other }
        format.html { redirect_to cemeteries_url, notice: "Cemetery was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_cemetery
      @cemetery = Cemetery.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def cemetery_params
      params.require(:cemetery).permit(
        :name,
        :description,
        address_attributes: [:id, :city, :country, :description, :name, :region, :street, :zipcode]
      )
    end
  end
end