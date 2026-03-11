module Hke
  class CsvImportJob
    include Sidekiq::Job

    def perform(csv_import_id)
	      csv_import = CsvImport.unscoped.find(csv_import_id)
	      csv_import.update!(status: :processing) unless csv_import.processing?

      Tempfile.create(["csv_import_#{csv_import.id}", ".csv"]) do |tmp|
        tmp.write(csv_import.csv_data)
        tmp.flush
        client = Hke::Import::CsvImportApiClient.new(
          file_path: tmp.path,
          csv_import_id: csv_import.id
        )
        client.run!
      end
    rescue StandardError => e
      csv_import&.update!(status: :failed)
      Hke::Logger.log(
        event_type: 'csv_import_failed',
        details: { csv_import_id: csv_import_id, error_message: e.message },
        error: e
      )
      raise
    end
  end
end
