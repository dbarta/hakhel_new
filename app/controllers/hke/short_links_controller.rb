module Hke
  class ShortLinksController < ActionController::Base
    def redirect
      link = ActsAsTenant.without_tenant do
        Hke::ShortLink.find_by(code: params[:code])
      end

      unless link
        render plain: "קישור לא נמצא", status: :not_found
        return
      end

      link.record_click!
      redirect_to portal_dashboard_path(link.contact_person.portal_token), allow_other_host: false
    end
  end
end
