class AddEmailStatusToHkeContactPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_contact_people, :email_status, :integer, default: 0, null: false
  end
end
