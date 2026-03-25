class AddRequireMessageApprovalToHkePreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_preferences, :require_message_approval, :boolean
  end
end
