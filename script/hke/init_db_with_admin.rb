# frozen_string_literal: true

require_relative "support/api_seeds_executor"

max_num_people = (ARGV.length > 0) ? ARGV[0].to_i : 1000
executor = ApiSeedsExecutor.new(max_num_people)

puts "@@@ Running script/hke/init_db_with_admin.rb"

executor.clear_database
executor.create_admin_account_community_system
