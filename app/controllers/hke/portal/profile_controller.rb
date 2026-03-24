module Hke
  module Portal
    class ProfileController < BaseController
      def show
      end

      def edit
      end

      def update
        if @contact.update(profile_params)
          redirect_to portal_profile_path(@portal_token), notice: t("hke.portal.profile.saved")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def profile_params
        params.require(:hke_contact_person).permit(:first_name, :last_name, :phone, :email)
      end
    end
  end
end
