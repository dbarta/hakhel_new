class Hke::SystemPreferencesController < Hke::PreferencesBaseController
  before_action :authenticate_user!
  prepend_before_action :set_preferring

  protected

  def after_update_path
    hke_system_preferences_path
  end

  def after_destroy_path
    hke_system_preferences_path
  end

  private

  def set_preferring
    @preferring = Hke::System.first!
  end
end
