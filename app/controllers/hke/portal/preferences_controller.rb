module Hke
  module Portal
    class PreferencesController < BaseController
      def show
        @preference = @contact.preference || @contact.build_preference
        @relations = @contact.relations.includes(:deceased_person, :preference)
      end

      def update
        @preference = @contact.preference || @contact.build_preference
        @relations = @contact.relations.includes(:deceased_person, :preference)

        if @preference.update(preference_params)
          redirect_to portal_preferences_path(@portal_token), notice: t("hke.portal.preferences.saved")
        else
          render :show, status: :unprocessable_entity
        end
      end

      def update_relation_preference
        @relation = @contact.relations.find(params[:relation_id])
        rel_pref = @relation.preference || @relation.build_preference

        if rel_pref.update(relation_preference_params)
          redirect_to portal_preferences_path(@portal_token), notice: t("hke.portal.preferences.saved")
        else
          redirect_to portal_preferences_path(@portal_token), alert: t("hke.portal.preferences.save_failed")
        end
      end

      private

      def preference_params
        params.require(:preference).permit(:delivery_priority, :how_many_days_before_yahrzeit_to_send_message,
          delivery_priority: [], how_many_days_before_yahrzeit_to_send_message: [])
      end

      def relation_preference_params
        params.require(:relation_preference).permit(:delivery_priority, delivery_priority: [])
      end
    end
  end
end
