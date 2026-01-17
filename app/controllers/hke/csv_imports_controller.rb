module Hke
  class CsvImportsController < ApplicationController
    include Hke::SetCommunityAsTenant
    before_action :authenticate_user!
    before_action :authorize_community_admin!

    def new
      @csv_import = CsvImport.new
      authorize @csv_import
    end

    def create
      @csv_import = CsvImport.new(csv_import_params)
      @csv_import.user = current_user
      @csv_import.community = ActsAsTenant.current_tenant
	    @csv_import.status = :processing
      authorize @csv_import

      if @csv_import.save
        # Process CSV in background with Sidekiq
        CsvImportJob.perform_async(@csv_import.id)
	      redirect_to hke_csv_import_path(@csv_import), notice: t('csv_imports.upload_success'), status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @csv_import = CsvImport.find(params[:id])
      authorize @csv_import
    end

    def index
      @csv_imports = policy_scope(CsvImport).includes(:user).order(created_at: :desc)
      authorize CsvImport
    end

    def destroy
      @csv_import = CsvImport.find(params[:id])
      authorize @csv_import
      @csv_import.destroy
	    redirect_to hke_csv_imports_path, notice: t('csv_imports.index.deleted', default: 'הלוג נמחק בהצלחה'), status: :see_other
    end

    def destroy_all
      authorize CsvImport, :destroy_all?

      imports = policy_scope(CsvImport)
      destroyed_count = 0

      imports.find_each do |import|
        destroyed_count += 1 if import.destroy
      end

	    redirect_to hke_csv_imports_path,
	                notice: t('csv_imports.index.cleared', count: destroyed_count, default: 'כל הלוגים נמחקו'),
	                status: :see_other
    end

    private

    def csv_import_params
	    # Hke::CsvImport uses param_key "hke_csv_import" (namespaced model)
	    params.require(CsvImport.model_name.param_key).permit(:file, :name)
    end

    def authorize_community_admin!
      unless current_user.community_admin? || current_user.system_admin?
	      redirect_to hke_root_path, alert: t('admin.dashboard.access_denied'), status: :see_other
      end
    end
  end
end
