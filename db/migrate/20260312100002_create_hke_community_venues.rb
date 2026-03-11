class CreateHkeCommunityVenues < ActiveRecord::Migration[8.1]
  def change
    create_table :hke_community_venues do |t|
      t.integer :community_id, null: false
      t.string :venue_type, null: false
      t.string :title, null: false
      t.text :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :hke_community_venues, :community_id
    add_index :hke_community_venues, [:community_id, :venue_type]
  end
end
