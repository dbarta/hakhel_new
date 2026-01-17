class Users::RegistrationsController < Devise::RegistrationsController
  layout "auth"

  before_action :load_collections, only: [:new, :create]

  def create
    build_resource(sign_up_params)
    apply_role_and_community(resource)

    Rails.logger.info("SIGNUP ATTRS: roles=#{resource.roles.inspect} community_id=#{resource.community_id.inspect}")

    resource.save
    if resource.persisted?
      sign_up(resource_name, resource)
      respond_with resource, location: after_sign_up_path_for(resource)
    else
      Rails.logger.error("SIGNUP FAIL: #{resource.errors.full_messages.join(', ')}")
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  private

  def build_resource(hash = {})
    super
    apply_role_and_community(resource)
  end

  def apply_role_and_community(user)
    selected_role = params.dig(:user, :role).presence
    user.roles ||= {}
    user.roles = {} if selected_role.present?
    user.roles[selected_role] = true if selected_role
    user.community_id = params.dig(:user, :community_id) if params.dig(:user, :community_id).present?
  end

  def sign_up_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :terms_of_service, :community_id)
  end

  def account_update_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :current_password, :terms_of_service, :community_id)
  end

  def load_collections
    @communities = Hke::Community.order(:name)
    @roles = %w[system_admin community_admin community_user]
  end
end
