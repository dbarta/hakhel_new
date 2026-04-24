module Hke
  module Portal
    class BaseController < ActionController::Base
      layout "hke/portal"

      include Pundit::Authorization

      helper Hke::PortalHelper
      helper Hke::ApplicationHelper

      before_action :set_portal_contact
      before_action :set_locale_hebrew
      before_action :set_current_portal_context

      # Pundit user is the portal contact person (ContactPerson), not a Devise user.
      # Policies can branch on user.is_a?(Hke::ContactPerson) vs AccountUser.
      def pundit_user
        @contact
      end

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

      def set_current_portal_context
        return unless @contact
        Current.portal_request = true
        Current.portal_contact = @contact
      end
    end
  end
end
