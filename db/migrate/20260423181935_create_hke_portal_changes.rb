class CreateHkePortalChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :hke_portal_changes do |t|
      t.references :contact_person, null: false,
                   foreign_key: { to_table: :hke_contact_people }
      t.integer :community_id, null: false
      t.string :change_type, null: false
      t.datetime :changed_at, null: false

      t.timestamps
    end

    add_index :hke_portal_changes, [:community_id, :changed_at]
  end
end
