class CreateHkeShortLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :hke_short_links do |t|
      t.string :code, null: false
      t.references :contact_person, null: false, foreign_key: { to_table: :hke_contact_people }
      t.string :via_token
      t.datetime :first_clicked_at
      t.integer :click_count, default: 0, null: false
      t.integer :community_id, null: false

      t.timestamps
    end

    add_index :hke_short_links, :code, unique: true
    add_index :hke_short_links, :community_id
  end
end
