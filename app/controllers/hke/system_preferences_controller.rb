class Hke::SystemPreferencesController < Hke::PreferencesBaseController
  before_action :authenticate_user!
  prepend_before_action :set_preferring

  protected

  def after_update_path
    raise NotImplementedError, "Define #after_update_path once routes/views exist for system preferences"
  end

  def after_destroy_path
    raise NotImplementedError, "Define #after_destroy_path once routes/views exist for system preferences"
  end

  private

  def set_preferring
    @preferring = Hke::System.first!
  end
end
