class CreateHkePortalVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :hke_portal_visits do |t|
      t.references :contact_person, null: false,
                   foreign_key: { to_table: :hke_contact_people }
      t.integer :community_id, null: false
      t.datetime :visited_at, null: false

      t.timestamps
    end

    add_index :hke_portal_visits, [:community_id, :visited_at]
  end
end
