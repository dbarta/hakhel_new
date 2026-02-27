class MigrateRolesToBooleanColumns < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Add boolean columns
    add_column :users, :system_admin, :boolean, default: false, null: false
    add_column :users, :community_admin, :boolean, default: false, null: false
    add_column :users, :community_user, :boolean, default: false, null: false

    # Step 2: Migrate data from jsonb roles column
    execute <<-SQL
      UPDATE users SET
        system_admin    = COALESCE((roles->>'system_admin')::boolean, false),
        community_admin = COALESCE((roles->>'community_admin')::boolean, false),
        community_user  = COALESCE((roles->>'community_user')::boolean, false)
      WHERE roles IS NOT NULL;
    SQL

    # Step 3: Remove the jsonb roles column
    remove_column :users, :roles
  end

  def down
    add_column :users, :roles, :jsonb, default: {}

    execute <<-SQL
      UPDATE users SET roles = json_build_object(
        'system_admin', system_admin,
        'community_admin', community_admin,
        'community_user', community_user
      )::jsonb;
    SQL

    remove_column :users, :system_admin
    remove_column :users, :community_admin
    remove_column :users, :community_user
  end
end
