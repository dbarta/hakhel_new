# frozen_string_literal: true

require_relative "support/api_seeds_executor"

include Hke::Loggable

max_num_people = ENV["MAX_IMPORT_ROWS"].present? ? ENV["MAX_IMPORT_ROWS"].to_i : 1000
init_logging "api_import_csv"
log_info "@@@ Running script/hke/import_from_csv.rb. Setting locale to :he. Importing no more than #{max_num_people} deceased people."

executor = ApiSeedsExecutor.new(max_num_people)
executor.process_csv(Rails.root.join("db", "data", "hke", "deceased_2022_02_28_no_blanks.csv"))
# executor.process_csv(Rails.root.join("db", "data", "hke", "test_deceased_1_deceased.csv"))
# executor.process_csv(Rails.root.join("db", "data", "hke", "deceased_2022_02_28_no_blanks_wrong_gender.csv"))
executor.summarize
