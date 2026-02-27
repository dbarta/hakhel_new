module Hke
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:edit, :update, :destroy]

    # GET /hke/users
    def index
      @users = policy_scope(User).includes(:community).order(:email)

      if params[:name_search]
        key = "%#{params[:name_search]}%"
        @users = @users.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", key, key, key)
      end

      @users.load

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(
              "search_results",
              partial: "hke/shared/search_results",
              locals: {
                items: @users,
                fields: [:name, :email, :created_at],
                other_fields: [
                  {header: t("users.index.roles"), data: "role_summary"},
                  {header: t("users.index.community"), data: "community_name"}
                ],
                actions: [
                  {name: "action_edit", path: :edit_hke_user_path},
                  {name: "action_delete", path: :hke_user_path, method: :delete, confirm: true}
                ]
              }
            )
          ]
        end
      end
    end

    def new
      @user = User.new
      authorize @user
      @communities = Hke::Community.all
    end

    def edit
      authorize @user
      @communities = Hke::Community.all
      @profile_mode = params[:id].blank?
      if @profile_mode
        session[:profile_return_to] = request.referer || hke_root_path
      end
    end

    def create
      @user = User.new(user_params)
      authorize @user
      @communities = Hke::Community.all

      @user.terms_of_service = true

      if Jumpstart.config.register_with_account?
        account = @user.owned_accounts.first_or_initialize
        account.account_users.new(user: @user, admin: true)
      end

      if @user.save
        redirect_to hke_users_path, notice: t("users.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      authorize @user
      @profile_mode = params[:id].blank?

      success = if @profile_mode && password_being_changed?
        if @user.update_with_password(user_params_with_password)
          bypass_sign_in(@user)
          true
        else
          false
        end
      elsif @profile_mode
        @user.update(profile_params)
      else
        @user.update(user_params)
      end

      if success
        if @profile_mode
          redirect_to session.delete(:profile_return_to) || hke_root_path, notice: t("users.updated")
        else
          redirect_to hke_users_path, notice: t("users.updated")
        end
      else
        @communities = Hke::Community.all
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @user

      if @user == current_user
        redirect_to hke_users_path, alert: t("users.cannot_delete_self")
        return
      end

      if @user.system_admin?
        if User.system_admin.count <= 1
          redirect_to hke_users_path, alert: t("users.cannot_delete_last_admin")
          return
        end
      end

      @user.destroy
      respond_to do |format|
        format.turbo_stream { redirect_to hke_users_path, notice: t("users.deleted"), status: :see_other }
        format.html { redirect_to hke_users_path, notice: t("users.deleted"), status: :see_other }
        format.json { head :no_content }
      end
    end

    private

    def set_user
      @user = params[:id].present? ? User.find(params[:id]) : current_user
    end

    def user_params
      params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation,
        :avatar, :community_id, :system_admin, :community_admin, :community_user)
    end

    def profile_params
      params.require(:user).permit(:first_name, :last_name, :email, :avatar)
    end

    def user_params_with_password
      params.require(:user).permit(:first_name, :last_name, :email, :avatar,
        :current_password, :password, :password_confirmation)
    end

    def password_being_changed?
      params[:user][:password].present?
    end
  end
end
