class Hke::PreferencesBaseController < ApplicationController
  # This controller is not intended to be routed directly.
  # Subclasses must set @preferring.

  before_action :set_preference

  def show
    render "hke/preferences/show"
  end

  def edit
    render "hke/preferences/edit"
  end

  def update
    if @preference.update(pref_params)
      redirect_to after_update_path
    else
      render "hke/preferences/edit", status: :unprocessable_entity
    end
  end

  def destroy
    @preference.destroy if @preference.persisted?
    redirect_to after_destroy_path
  end

  # ---------- NEW ----------
  # Preview how many FutureMessages will be impacted by this change
  def impact_preview
    raise NotImplementedError, "Subclasses must set @preferring" if @preferring.nil?

    pref = @preferring.preference || @preferring.build_preference
    pref.assign_attributes(pref_params)

    impact =
      if pref.send(:impactful_rebuild_change?)
        pref.send(:rebuild_impact_count)
      else
        0
      end

    render json: {impact_count: impact}
  end

  protected

  def after_update_path
    raise NotImplementedError, "Subclasses must implement #after_update_path"
  end

  def after_destroy_path
    raise NotImplementedError, "Subclasses must implement #after_destroy_path"
  end

  private

  def set_preference
    raise NotImplementedError, "Subclasses must set @preferring" if @preferring.nil?
    @preference = @preferring.preference || @preferring.build_preference
  end

  def pref_params
    params.require(:hke_preference).permit(
      :attempt_to_resend_if_no_sent_on_time,
      :daily_sweep_job_time,
      :enable_fallback_delivery_method,
      :send_window_start_time,
      how_many_days_before_yahrzeit_to_send_message: [],
      delivery_priority: []
    )
  end
end
