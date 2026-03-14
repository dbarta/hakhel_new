module Hke
  module Portal
    class DeceasedController < BaseController
      include Hke::HebrewSelects
      helper_method :gender_select, :hebrew_month_select, :hebrew_day_select

      before_action :set_deceased_person

      def show
      end

      def edit
      end

      def update
        if @deceased.update(deceased_params)
          redirect_to portal_dashboard_path(@portal_token), notice: "הפרטים עודכנו בהצלחה"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @relation.destroy
        redirect_to portal_dashboard_path(@portal_token), notice: "הנפטר הוסר מרשימתך"
      end

      private

      def set_deceased_person
        @relation = @contact.relations.includes(:deceased_person).find_by(deceased_person_id: params[:id])
        unless @relation
          render plain: "נפטר לא נמצא", status: :not_found and return
        end
        @deceased = @relation.deceased_person
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
