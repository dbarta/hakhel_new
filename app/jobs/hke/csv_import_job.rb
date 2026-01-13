module Hke
  class CsvImportJob
    include Sidekiq::Job

    def perform(csv_import_id)
      csv_import = CsvImport.find(csv_import_id)

      csv_import.file.open do |io|
        client = Hke::Import::CsvImportApiClient.new(
          file_path: io.path,
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
