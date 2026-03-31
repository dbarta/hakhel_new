class AddCreatedAtIndexesToHkeSentAndNotSentMessages < ActiveRecord::Migration[8.1]
  def change
    # Composite index: acts_as_tenant scopes by community_id, dashboard counts filter by created_at
    add_index :hke_sent_messages, [:community_id, :created_at],
              name: "index_hke_sent_messages_on_community_id_and_created_at"
    add_index :hke_not_sent_messages, [:community_id, :created_at],
              name: "index_hke_not_sent_messages_on_community_id_and_created_at"
  end
end
