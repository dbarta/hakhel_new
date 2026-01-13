class Hke::Api::V1::ImportDataController < Hke::Api::BaseController

  # Skip Pundit authorization for file upload - this is a utility endpoint
  skip_after_action :verify_authorized

  def upload
    # Only system admins can upload data
    unless current_user.system_admin?
      render json: { error: "Access denied" }, status: :forbidden and return
    end

    # Ensure that the file was provided
    if params[:file].nil?
      render json: { error: "No file uploaded" }, status: :unprocessable_entity and return
    end

    # Save the uploaded file to a temporary location
    uploaded_file = params[:file]
    file_path = Rails.root.join('tmp', uploaded_file.original_filename)

    # Write the file to disk
    File.open(file_path, 'wb') do |file|
      file.write(uploaded_file.read)
    end

    render json: { message: "File uploaded successfully", file_path: file_path.to_s }, status: :ok
  end
end
