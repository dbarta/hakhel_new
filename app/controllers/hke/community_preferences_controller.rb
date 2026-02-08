class Hke::CommunityPreferencesController < Hke::PreferencesBaseController
  include Hke::SetCommunityAsTenant

  before_action :authenticate_user!
  prepend_before_action :set_community_as_current_tenant
  prepend_before_action :set_preferring

  protected

  def after_update_path
    raise NotImplementedError, "Define #after_update_path once routes/views exist for community preferences"
  end

  def after_destroy_path
    raise NotImplementedError, "Define #after_destroy_path once routes/views exist for community preferences"
  end

  private

  def set_preferring
    @preferring = ActsAsTenant.current_tenant
  end
end
