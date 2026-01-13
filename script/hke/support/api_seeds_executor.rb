# frozen_string_literal: true

require_relative "api_seeds_helper"
require_relative "seeds_helper"

class ApiSeedsExecutor
  include Hke::ApiSeedsHelper
  include Hke::ApiHelper
  include Hke::Loggable
  include Hke::ApplicationHelper
  include SeedsHelper

  def initialize(max_num_people)
    @max_num_people = max_num_people
  end

  def process_csv(file_path)
    csv_client = Hke::Import::CsvImportApiClient.new(file_path: file_path, max_rows: @max_num_people)
    csv_client.run!
    @last_client = csv_client
  end

  def summarize
    @last_client&.summarize
  end
end
