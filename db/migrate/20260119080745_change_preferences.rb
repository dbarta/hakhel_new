class ChangePreferences < ActiveRecord::Migration[8.1]
  def up
    # New fields
    add_column :hke_preferences, :delivery_priority, :string, array: true
    add_column :hke_preferences, :enable_fallback_delivery_method, :boolean
    add_column :hke_preferences, :daily_sweep_job_time, :time
    add_column :hke_preferences, :time_zone, :string

    # Build delivery_priority from old booleans
    execute <<~SQL
      UPDATE hke_preferences
      SET delivery_priority = (
        ARRAY[
          CASE WHEN enable_send_sms THEN 'sms' END,
          CASE WHEN enable_send_whatsapp THEN 'whatsapp' END,
          CASE WHEN enable_send_email THEN 'email' END
        ]::text[]
      );
    SQL

    # Remove nulls from array
    execute <<~SQL
      UPDATE hke_preferences
      SET delivery_priority = array_remove(delivery_priority, NULL);
    SQL

    # Fallback enabled if more than one method
    execute <<~SQL
      UPDATE hke_preferences
      SET enable_fallback_delivery_method = (array_length(delivery_priority, 1) > 1);
    SQL

    # Default sweep time if not set
    execute <<~SQL
      UPDATE hke_preferences
      SET daily_sweep_job_time = '03:00'
      WHERE daily_sweep_job_time IS NULL;
    SQL

    # Remove old delivery flags
    remove_column :hke_preferences, :enable_send_sms
    remove_column :hke_preferences, :enable_send_whatsapp
    remove_column :hke_preferences, :enable_send_email
  end

  def down
    add_column :hke_preferences, :enable_send_sms, :boolean, default: true
    add_column :hke_preferences, :enable_send_whatsapp, :boolean, default: true
    add_column :hke_preferences, :enable_send_email, :boolean, default: true

    execute <<~SQL
      UPDATE hke_preferences
      SET
        enable_send_sms = ('sms' = ANY(delivery_priority)),
        enable_send_whatsapp = ('whatsapp' = ANY(delivery_priority)),
        enable_send_email = ('email' = ANY(delivery_priority));
    SQL

    remove_column :hke_preferences, :delivery_priority
    remove_column :hke_preferences, :enable_fallback_delivery_method
    remove_column :hke_preferences, :daily_sweep_job_time
    remove_column :hke_preferences, :time_zone
  end
end
