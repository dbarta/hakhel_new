class AddPortalTokenToHkeContactPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_contact_people, :portal_token, :string
    add_index :hke_contact_people, :portal_token, unique: true
  end
end
