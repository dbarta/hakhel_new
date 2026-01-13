module Hke
  module Admin
    class SystemPreferencesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_system, only: [:show, :edit, :update]

      # Skip Pundit callbacks and re-enable them for the actions we do have
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped
      after_action :verify_authorized, only: [:show, :edit, :update]

      def show
        authorize @system
        @preference = @system.preference || @system.build_preference
      end

      def edit
        authorize @system
        @preference = @system.preference || @system.build_preference
      end

      def update
        authorize @system
        @preference = @system.preference || @system.build_preference

        if @preference.update(preference_params)
          redirect_to hke_admin_system_preferences_path, notice: 'System preferences were successfully updated.'
        else
          render :edit
        end
      end

      private

      def set_system
        @system = Hke::System.instance
      end

      def preference_params
        params.require(:preference).permit(
          :enable_send_email,
          :enable_send_sms,
          :enable_send_whatsapp,
          :attempt_to_resend_if_no_sent_on_time,
          how_many_days_before_yahrzeit_to_send_message: []
        )
      end


    end
  end
end
