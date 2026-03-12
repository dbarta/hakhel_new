module Hke
  module Portal
    class BaseController < ActionController::Base
      layout "hke/portal"

      helper Hke::PortalHelper
      helper Hke::ApplicationHelper

      before_action :set_portal_contact
      before_action :set_locale_hebrew

      private

      def set_locale_hebrew
        I18n.locale = :he
      end

      def set_portal_contact
        @portal_token = params[:portal_token]
        ActsAsTenant.without_tenant do
          @contact = Hke::ContactPerson.find_by(portal_token: @portal_token)
        end
        unless @contact
          render plain: "קישור לא תקין", status: :not_found
          return
        end

        ActsAsTenant.current_tenant = @contact.community
      end
    end
  end
end
