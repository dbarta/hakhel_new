class Users::SessionsController < Devise::SessionsController
  layout "auth"

  # Remove Devise success notices on sign-in and sign-out
  after_action :clear_sign_in_notice, only: :create
  after_action :clear_sign_out_notice, only: :destroy

  def create
    super do |_resource|
      flash.delete(:notice)
    end
  end

  def destroy
    super do
      flash.delete(:notice)
    end
  end

  def after_sign_in_path_for(resource)
    return hke_admin_root_path if resource.respond_to?(:system_admin?) && resource.system_admin?
    return hke_root_path if resource.respond_to?(:community_admin?) && resource.community_admin?
    return hke_root_path if resource.respond_to?(:community_user?) && resource.community_user?
    hke_root_path
  end

  private

  def clear_sign_in_notice
    flash.delete(:notice) if warden.authenticated?(:user)
  end

  def clear_sign_out_notice
    flash.delete(:notice)
  end
end
