# frozen_string_literal: true

module Hke
  # Wraps the database clear + re-seed logic from script/hke/init_db_with_admin.rb
  # so it can be invoked from the system-admin advanced tools web UI.
  class DbInitializerService
    include Hke::ApiHelper
    include Hke::Loggable
  end
end
