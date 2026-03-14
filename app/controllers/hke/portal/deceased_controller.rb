module Hke
  module Portal
    class DeceasedController < BaseController
      include Hke::HebrewSelects
      helper_method :gender_select, :hebrew_month_select, :hebrew_day_select

      before_action :set_deceased_person

      def show
        authorize @deceased
      end

      def edit
        authorize @deceased
      end

      def update
        authorize @deceased
        if @deceased.update(deceased_params)
          redirect_to portal_dashboard_path(@portal_token), notice: "הפרטים עודכנו בהצלחה"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @deceased
        # In portal context: remove the relation (not the deceased record itself)
        @relation.destroy
        redirect_to portal_dashboard_path(@portal_token), notice: "הנפטר הוסר מרשימתך"
      end

      private

      def set_deceased_person
        @deceased = Hke::DeceasedPerson.find_by(id: params[:id])
        unless @deceased
          render plain: "נפטר לא נמצא", status: :not_found and return
        end
        # Load the relation for use in destroy; policy checks authorization
        @relation = @contact.relations.find_by(deceased_person_id: @deceased.id)
      end

      def deceased_params
        params.require(:deceased_person).permit(
          :first_name, :last_name, :gender,
          :hebrew_year_of_death, :hebrew_month_of_death, :hebrew_day_of_death,
          :date_of_death, :occupation, :organization, :religion,
          :father_first_name, :mother_first_name, :time_of_death, :location_of_death
        )
      end
    end
  end
end
