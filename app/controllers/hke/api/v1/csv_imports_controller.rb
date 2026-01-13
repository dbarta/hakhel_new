module Hke
  module Api
    module V1
      class CsvImportsController < Hke::Api::BaseController
        include Hke::SetCommunityAsTenant

        before_action :set_csv_import, only: [:show, :update]

        def index
          @csv_imports = policy_scope(Hke::CsvImport).order(created_at: :desc)
          render json: @csv_imports
        end

        def show
          authorize @csv_import
          render json: @csv_import, include: :logs
        end

        def create
          @csv_import = Hke::CsvImport.new(csv_import_params)
          @csv_import.user = current_user
          @csv_import.community = ActsAsTenant.current_tenant
          authorize @csv_import
          if @csv_import.save
            render json: @csv_import, status: :created
          else
            render json: { errors: @csv_import.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          authorize @csv_import
          if @csv_import.update(csv_import_params)
            render json: @csv_import, status: :ok
          else
            render json: { errors: @csv_import.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_csv_import
          @csv_import = Hke::CsvImport.find(params[:id])
        end

        def csv_import_params
          params.require(:csv_import).permit(
            :name,
            :status,
            :import_type,
            :total_rows,
            :processed_rows,
            :successful_rows,
            :failed_rows,
            :errors_data,
            :total_deceased_in_input,
            :total_contacts_in_input,
            :new_deceased,
            :existing_deceased,
            :file
          )
        end
      end
    end
  end
end

