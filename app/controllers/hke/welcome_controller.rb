module Hke
  class WelcomeController < ApplicationController
    def index
      if user_signed_in?
        if current_user.system_admin?
          redirect_to hke_admin_root_path
        elsif current_user.community_admin? || current_user.community_user?
          redirect_to hke_root_path
        else
          redirect_to hke_root_path
        end
      else
        render layout: "hke/welcome"
      end
    end
  end
end
