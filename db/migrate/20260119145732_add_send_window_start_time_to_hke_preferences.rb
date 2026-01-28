class AddSendWindowStartTimeToHkePreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_preferences, :send_window_start_time, :time
  end
end
