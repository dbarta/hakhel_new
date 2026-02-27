class CreateHkeNotSentMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :hke_not_sent_messages do |t|
      t.string :messageable_type, null: false
      t.bigint :messageable_id, null: false
      t.date :send_date
      t.text :full_message
      t.integer :message_type
      t.integer :delivery_method
      t.string :email
      t.string :phone
      t.string :token
      t.integer :reason, null: false, default: 0
      t.text :error_message
      t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint

      t.timestamps
    end

    add_index :hke_not_sent_messages, [:messageable_type, :messageable_id], name: "index_hke_not_sent_messages_on_messageable"
    add_index :hke_not_sent_messages, :token
    add_index :hke_not_sent_messages, :reason
  end
end
