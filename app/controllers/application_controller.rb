class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  include Accounts::SubscriptionStatus,
    ActiveStorage::SetCurrent,
    Authentication,
    Authorization,
    DeviceFormat,
    Pagination,
    SetCurrentRequestDetails,
    SetLocale,
    Sortable,
    Users::AgreementUpdates,
    Users::NavbarNotifications,
    Users::Sudo

  protected

  # Direct role-based routing for HKE users after login
  def after_sign_in_path_for(resource_or_scope)
    return stored_location_for(resource_or_scope) if stored_location_for(resource_or_scope)

    if resource_or_scope.is_a?(User)
      if resource_or_scope.system_admin?
        hke_admin_root_path
      elsif resource_or_scope.community_admin? || resource_or_scope.community_user?
        hke_root_path
      else
        super
      end
    else
      super
    end
  end
end
