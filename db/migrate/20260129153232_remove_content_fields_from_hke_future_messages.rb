class RemoveContentFieldsFromHkeFutureMessages < ActiveRecord::Migration[8.1]
  def change
    remove_column :hke_future_messages, :full_message, :text
    remove_column :hke_future_messages, :contact_first_name, :string
    remove_column :hke_future_messages, :contact_last_name, :string
    remove_column :hke_future_messages, :deceased_first_name, :string
    remove_column :hke_future_messages, :deceased_last_name, :string
    remove_column :hke_future_messages, :relation_of_deceased_to_contact, :string
    remove_column :hke_future_messages, :date_of_death, :date
    remove_column :hke_future_messages, :hebrew_year_of_death, :string
    remove_column :hke_future_messages, :hebrew_month_of_death, :string
    remove_column :hke_future_messages, :hebrew_day_of_death, :string
    remove_column :hke_future_messages, :metadata, :json
  end
end
