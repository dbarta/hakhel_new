class CreateHkeAndCustomSchemaBaseline < ActiveRecord::Migration[8.0]
  def change
    enable_extension "plpgsql" unless extension_enabled?("plpgsql")

    unless table_exists?(:hke_communities)
      create_table :hke_communities do |t|
        t.string :name, null: false
        t.string :community_type, null: false
        t.references :account, null: false, foreign_key: true
        t.string :description
        t.string :phone_number
        t.string :email_address
        t.timestamps
      end
    end

    unless table_exists?(:hke_addresses)
      create_table :hke_addresses do |t|
        t.string :name
        t.string :description
        t.string :street
        t.string :city
        t.string :region
        t.string :country
        t.string :zipcode
        t.string :addressable_type, null: false
        t.bigint :addressable_id, null: false
        t.timestamps
        t.index [:addressable_type, :addressable_id], name: "index_hke_addresses_on_addressable"
      end
    end

    unless table_exists?(:hke_cemeteries)
      create_table :hke_cemeteries do |t|
        t.string :name
        t.string :description
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.timestamps
      end
    end

    unless table_exists?(:hke_contact_people)
      create_table :hke_contact_people do |t|
        t.string :first_name
        t.string :last_name
        t.string :email
        t.string :phone
        t.string :gender
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.timestamps
      end
    end

    unless table_exists?(:hke_deceased_people)
      create_table :hke_deceased_people do |t|
        t.string :first_name
        t.string :last_name
        t.string :gender
        t.string :occupation
        t.string :organization
        t.string :religion
        t.string :father_first_name
        t.string :mother_first_name
        t.string :hebrew_year_of_death
        t.string :hebrew_month_of_death
        t.string :hebrew_day_of_death
        t.string :location_of_death
        t.references :cemetery, foreign_key: {to_table: :hke_cemeteries}, type: :bigint
        t.string :cemetery_region
        t.string :cemetery_parcel
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.datetime :date_of_death
        t.time :time_of_death
        t.timestamps
      end
    end

    unless table_exists?(:hke_selections)
      create_table :hke_selections do |t|
        t.string :name
        t.string :description
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.timestamps
      end
    end

    unless table_exists?(:hke_relations)
      create_table :hke_relations do |t|
        t.string :relation_of_deceased_to_contact
        t.string :token
        t.references :deceased_person, null: false, foreign_key: {to_table: :hke_deceased_people}, type: :bigint
        t.references :contact_person, null: false, foreign_key: {to_table: :hke_contact_people}, type: :bigint
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.timestamps
      end
    end

    unless table_exists?(:hke_relations_selections)
      create_table :hke_relations_selections do |t|
        t.references :relation, null: false, foreign_key: {to_table: :hke_relations}, type: :bigint
        t.references :selection, null: false, foreign_key: {to_table: :hke_selections}, type: :bigint
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.timestamps
      end
    end

    unless table_exists?(:hke_preferences)
      create_table :hke_preferences do |t|
        t.string :preferring_type, null: false
        t.bigint :preferring_id, null: false
        t.boolean :enable_send_email, default: true
        t.boolean :enable_send_sms, default: true
        t.boolean :enable_send_whatsapp, default: true
        t.integer :how_many_days_before_yahrzeit_to_send_message, default: [7], array: true
        t.boolean :attempt_to_resend_if_no_sent_on_time
        t.timestamps
        t.index [:preferring_type, :preferring_id], name: "index_hke_preferences_on_preferring"
      end
    end

    unless table_exists?(:hke_future_messages)
      create_table :hke_future_messages do |t|
        t.string :messageable_type, null: false
        t.bigint :messageable_id, null: false
        t.datetime :send_date
        t.text :full_message
        t.integer :message_type
        t.json :metadata
        t.integer :delivery_method
        t.string :email
        t.string :phone
        t.string :token
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.string :deceased_first_name
        t.string :deceased_last_name
        t.string :contact_first_name
        t.string :contact_last_name
        t.string :hebrew_year_of_death
        t.string :hebrew_month_of_death
        t.string :hebrew_day_of_death
        t.string :relation_of_deceased_to_contact
        t.date :date_of_death
        t.integer :approval_status, default: 0
        t.datetime :approved_at
        t.references :approved_by, foreign_key: {to_table: :users}, type: :bigint
        t.timestamps
        t.index :approval_status, name: "index_hke_future_messages_on_approval_status"
        t.index [:messageable_type, :messageable_id], name: "index_hke_future_messages_on_messageable"
        t.index :token, unique: true, name: "index_hke_future_messages_on_token"
      end
    end

    unless table_exists?(:hke_sent_messages)
      create_table :hke_sent_messages do |t|
        t.string :messageable_type, null: false
        t.bigint :messageable_id, null: false
        t.datetime :send_date
        t.text :full_message
        t.integer :message_type
        t.json :metadata
        t.integer :delivery_method
        t.string :email
        t.string :phone
        t.string :token
        t.string :twilio_message_sid
        t.string :deceased_first_name
        t.string :deceased_last_name
        t.string :contact_first_name
        t.string :contact_last_name
        t.string :hebrew_year_of_death
        t.string :hebrew_month_of_death
        t.string :hebrew_day_of_death
        t.string :relation_of_deceased_to_contact
        t.date :date_of_death
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.timestamps
        t.index [:messageable_type, :messageable_id], name: "index_hke_sent_messages_on_messageable"
        t.index :token, unique: true, name: "index_hke_sent_messages_on_token"
        t.index :twilio_message_sid, unique: true, name: "index_hke_sent_messages_on_twilio_message_sid"
      end
    end

    unless table_exists?(:hke_landing_pages)
      create_table :hke_landing_pages do |t|
        t.string :name
        t.text :body
        t.references :user, null: false, foreign_key: true, type: :bigint
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.timestamps
      end
    end

    unless table_exists?(:hke_csv_imports)
      create_table :hke_csv_imports do |t|
        t.integer :status, default: 0
        t.integer :import_type, default: 0
        t.integer :total_rows, default: 0
        t.integer :processed_rows, default: 0
        t.integer :successful_rows, default: 0
        t.integer :failed_rows, default: 0
        t.text :errors_data
        t.references :user, null: false, foreign_key: true, type: :bigint
        t.references :community, null: false, foreign_key: {to_table: :hke_communities}, type: :bigint
        t.string :name
        t.integer :total_deceased_in_input, default: 0
        t.integer :total_contacts_in_input, default: 0
        t.integer :new_deceased, default: 0
        t.integer :existing_deceased, default: 0
        t.timestamps
      end
    end

    unless table_exists?(:hke_csv_import_logs)
      create_table :hke_csv_import_logs do |t|
        t.references :csv_import, null: false, foreign_key: {to_table: :hke_csv_imports}, type: :bigint
        t.string :level, null: false
        t.integer :row_number
        t.text :message, null: false
        t.jsonb :details
        t.timestamps
      end
    end

    unless table_exists?(:hke_logs)
      create_table :hke_logs do |t|
        t.string :event_type, null: false
        t.string :entity_type
        t.bigint :entity_id
        t.string :message_token
        t.bigint :user_id
        t.bigint :community_id
        t.inet :ip_address
        t.datetime :event_time, null: false
        t.jsonb :details, default: {}
        t.string :error_type
        t.text :error_message
        t.text :error_trace
        t.timestamps
        t.index :community_id, name: "index_hke_logs_on_community_id"
        t.index [:entity_type, :entity_id], name: "index_hke_logs_on_entity_type_and_entity_id"
        t.index :message_token, name: "index_hke_logs_on_message_token"
        t.index :user_id, name: "index_hke_logs_on_user_id"
      end
    end

    unless table_exists?(:hke_systems)
      create_table :hke_systems do |t|
        t.string :product_name, default: "Hakhel"
        t.string :version, default: "1.0"
        t.timestamps
      end
    end

    unless column_exists?(:users, :roles)
      add_column :users, :roles, :jsonb, default: {}, null: false
    end
    add_index :users, :roles, using: :gin, name: "index_users_on_roles" unless index_exists?(:users, :roles, name: "index_users_on_roles")

    unless column_exists?(:users, :community_id)
      add_column :users, :community_id, :bigint
    end
    add_index :users, :community_id, name: "index_users_on_community_id" unless index_exists?(:users, :community_id, name: "index_users_on_community_id")
    add_foreign_key :users, :hke_communities, column: :community_id unless foreign_key_exists?(:users, :hke_communities, column: :community_id)

    add_index :account_users, :account_id, name: "index_account_users_on_account_id" unless index_exists?(:account_users, :account_id, name: "index_account_users_on_account_id")
    add_index :account_users, :user_id, name: "index_account_users_on_user_id" unless index_exists?(:account_users, :user_id, name: "index_account_users_on_user_id")
  end
end
