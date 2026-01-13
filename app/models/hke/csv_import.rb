module Hke
  class CsvImport < CommunityRecord
    belongs_to :user
    has_one_attached :file
    has_many :logs, class_name: "Hke::CsvImportLog", dependent: :destroy

    # Enable Turbo Stream broadcasting
    broadcasts

    enum :status, {
      pending: 0,
      processing: 1,
      completed: 2,
      failed: 3
    }

    enum :import_type, {
      deceased_people: 0,
      contact_people: 1,
      combined: 2
    }

    validates :file, presence: true
    validate :file_is_csv

    # Statistics tracking
    attribute :total_rows, :integer, default: 0
    attribute :processed_rows, :integer, default: 0
    attribute :successful_rows, :integer, default: 0
    attribute :failed_rows, :integer, default: 0
    attribute :errors_data, :text # JSON string of errors
    attribute :total_deceased_in_input, :integer, default: 0
    attribute :total_contacts_in_input, :integer, default: 0
    attribute :new_deceased, :integer, default: 0
    attribute :existing_deceased, :integer, default: 0

    scope :recent, -> { order(created_at: :desc) }
    scope :by_status, ->(status) { where(status: status) }

    def progress_percentage
      return 0 if total_rows.zero?
      (processed_rows.to_f / total_rows * 100).round(2)
    end

    def errors_list
      return [] if errors_data.blank?
      JSON.parse(errors_data)
    rescue JSON::ParserError
      []
    end

    def add_error(row_number, error_message)
      errors = errors_list
      errors << {row: row_number, message: error_message}
      self.errors_data = errors.to_json
    end

    def success_rate
      return 0 if processed_rows.zero?
      (successful_rows.to_f / processed_rows * 100).round(2)
    end

    def can_retry?
      failed? && failed_rows > 0
    end

    private

    def file_is_csv
      return unless file.attached?

      unless file.content_type == "text/csv" || file.filename.extension.downcase == "csv"
        errors.add(:file, "must be a CSV file")
      end
    end
  end
end
