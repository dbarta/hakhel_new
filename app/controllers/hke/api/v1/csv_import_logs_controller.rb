module Hke
  module Api
    module V1
      class CsvImportLogsController < Hke::Api::BaseController
        include Hke::SetCommunityAsTenant
        skip_after_action :verify_policy_scoped

        def create
          csv_import = Hke::CsvImport.find(log_params[:csv_import_id])
          authorize Hke::CsvImportLog

          log_entry = csv_import.logs.build(log_params.except(:csv_import_id))

          if log_entry.save
            render json: log_entry, status: :created
          else
            render json: { errors: log_entry.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def log_params
          params.require(:csv_import_log).permit(
            :csv_import_id,
            :level,
            :row_number,
            :message,
            :details
          )
        end
      end
    end
  end
end

