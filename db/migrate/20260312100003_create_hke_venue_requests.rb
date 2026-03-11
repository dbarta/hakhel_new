class CreateHkeVenueRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :hke_venue_requests do |t|
      t.integer :community_id, null: false
      t.references :contact_person, null: false, foreign_key: { to_table: :hke_contact_people }
      t.references :community_venue, null: false, foreign_key: { to_table: :hke_community_venues }
      t.references :relation, null: true, foreign_key: { to_table: :hke_relations }
      t.string :status, default: "pending", null: false
      t.datetime :sent_email_at
      t.text :note

      t.timestamps
    end

    add_index :hke_venue_requests, :community_id
    add_index :hke_venue_requests, :status
  end
end
