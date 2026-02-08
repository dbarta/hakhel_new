class Hke::CommunityPreferencesController < Hke::PreferencesBaseController
  include Hke::SetCommunityAsTenant

  prepend_before_action :set_community_as_current_tenant
  prepend_before_action :set_preferring   # ← change here

  protected

  def after_update_path
    hke_community_preferences_path
  end

  def after_destroy_path
    hke_community_preferences_path
  end

  private

  # def set_preferring
  #   @preferring = ActsAsTenant.current_tenant
  # end

  def set_preferring
    id = session[:selected_community_id]
    raise "No selected community in session" if id.blank?

    @preferring = Hke::Community.find(id)
  end
end
