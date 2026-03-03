class RemoveDefaultFromPreferenceDaysBeforeYahrzeit < ActiveRecord::Migration[8.1]
  def change
    change_column_default :hke_preferences, :how_many_days_before_yahrzeit_to_send_message, from: [7], to: nil
  end
end
