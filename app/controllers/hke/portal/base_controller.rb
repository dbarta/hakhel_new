module Hke
  module Portal
    class BaseController < ActionController::Base
      layout "hke/portal"

      before_action :set_portal_contact
      before_action :set_locale_hebrew

      helper_method :portal_nav_link

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

        # Set tenant to the contact's community
        ActsAsTenant.current_tenant = @contact.community
      end

      def portal_nav_link(label:, path:, icon:, **_opts)
        active = request.path.start_with?(path)
        css = active ? "active" : ""
        svg = portal_icon(icon)
        link_to path, class: css do
          "#{svg}<span>#{label}</span>".html_safe
        end
      end

      def portal_icon(name)
        icons = {
          home: '<svg viewBox="0 0 24 24" style="width:1.4rem;height:1.4rem;stroke:currentColor;fill:none;stroke-width:1.5;"><path d="M3 9.5L12 3l9 6.5V20a1 1 0 01-1 1H4a1 1 0 01-1-1V9.5z"/><path d="M9 21V12h6v9"/></svg>',
          user: '<svg viewBox="0 0 24 24" style="width:1.4rem;height:1.4rem;stroke:currentColor;fill:none;stroke-width:1.5;"><circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/></svg>',
          sliders: '<svg viewBox="0 0 24 24" style="width:1.4rem;height:1.4rem;stroke:currentColor;fill:none;stroke-width:1.5;"><line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/><circle cx="9" cy="6" r="2" fill="white" stroke="currentColor"/><circle cx="15" cy="12" r="2" fill="white" stroke="currentColor"/><circle cx="9" cy="18" r="2" fill="white" stroke="currentColor"/></svg>',
          star: '<svg viewBox="0 0 24 24" style="width:1.4rem;height:1.4rem;stroke:currentColor;fill:none;stroke-width:1.5;"><polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26"/></svg>'
        }
        icons[name] || ""
      end
    end
  end
end
