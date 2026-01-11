module Hke
  class CsvImportLog < ApplicationRecord
    self.table_name = 'hke_csv_import_logs'

    belongs_to :csv_import, class_name: 'Hke::CsvImport'

    enum :level, { info: 'info', warn: 'warn', error: 'error' }

    validates :message, presence: true
  end
end

