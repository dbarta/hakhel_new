class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_system_admin
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    @users = User.includes(:community).order(:email)
    @users.load

    @system_admins = @users.select(&:system_admin?)
    @community_admins = @users.select(&:community_admin?)
    @community_users = @users.select(&:community_user?)

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
                {header: t("admin.users.index.roles"), data: "role_summary"},
                {header: t("admin.users.index.community"), data: "community_name"}
              ],
              actions: [
                {name: "action_edit", path: :edit_madmin_user_path},
                {name: "action_delete", path: :madmin_user_path, method: :delete, confirm: true}
              ]
            }
          ),
          turbo_stream.update("users_count", @users.count)
        ]
      end
    end
  end

  def show
    @user_accounts = @user.accounts
    @user_communities = @user.community ? [@user.community] : []
  end

  def new
    @user = User.new
    @communities = Hke::Community.all
  end

  def create
    @user = User.new(user_params)
    @communities = Hke::Community.all

    @user.terms_of_service = true
    @user.skip_confirmation!
    assign_roles(@user, user_params)

    if Jumpstart.config.register_with_account?
      account = @user.owned_accounts.first_or_initialize
      account.account_users.new(user: @user, admin: true)
    end

    if @user.save
      if params[:user][:community_id].present?
        community = Hke::Community.find(params[:user][:community_id])
        @user.update(community: community)
      end
      redirect_to "/admin/users/#{@user.id}", notice: t("users.created")
    else
      render :new
    end
  end

  def edit
    @communities = Hke::Community.all
  end

  def update
    assign_roles(@user, user_params)

    if @user.update(user_params)
      if params[:user][:community_id].present?
        community = Hke::Community.find(params[:user][:community_id])
        @user.update(community: community)
      end
      redirect_to user_path(@user), notice: t("users.updated")
    else
      @communities = Hke::Community.all
      render :edit
    end
  end

  def destroy
    if @user == current_user
      redirect_to "/admin/users", alert: t("users.cannot_delete_self")
      return
    end

    if @user.system_admin?
      system_admin_count = User.where("roles ? 'system_admin'").count
      if system_admin_count <= 1
        redirect_to "/admin/users", alert: t("users.cannot_delete_last_admin")
        return
      end
    end

    @user.destroy
    respond_to do |format|
      format.turbo_stream { redirect_to "/admin/users", notice: t("users.deleted"), status: :see_other }
      format.html { redirect_to "/admin/users", notice: t("users.deleted"), status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation,
      :community_id, :system_admin, :community_admin, :community_user)
  end

  def assign_roles(user, user_params)
    return unless user_params

    user.roles = {}
    user.roles[:system_admin] = true if user_params[:system_admin] == "true"
    user.roles[:community_admin] = true if user_params[:community_admin] == "true"
    user.roles[:community_user] = true if user_params[:community_user] == "true"
  end

  def ensure_system_admin
    unless current_user.system_admin?
      redirect_to root_path, alert: "Access denied. System admin privileges required."
    end
  end
end
