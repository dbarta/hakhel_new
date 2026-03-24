class AddSendgridMessageIdToHkeSentMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_sent_messages, :sendgrid_message_id, :string
    add_index :hke_sent_messages, :sendgrid_message_id
  end
end
