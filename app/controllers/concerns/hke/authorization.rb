module Hke
  module Authorization
    extend ActiveSupport::Concern
    include Pundit::Authorization

    # Use User directly for Hke role-based authorization
    def pundit_user
      current_user
    end

    private

    def user_not_authorized
      redirect_back_or_to root_path, alert: t("unauthorized")
    end
  end
end
