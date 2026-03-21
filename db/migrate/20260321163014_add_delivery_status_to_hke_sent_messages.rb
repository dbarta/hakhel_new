class AddDeliveryStatusToHkeSentMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :hke_sent_messages, :delivery_status, :string       # queued/sending/sent/delivered/undelivered/failed
    add_column :hke_sent_messages, :twilio_error_code, :string     # e.g. "30003"
    add_column :hke_sent_messages, :twilio_error_message, :string  # human-readable error from Twilio
    add_index  :hke_sent_messages, :delivery_status
  end
end
