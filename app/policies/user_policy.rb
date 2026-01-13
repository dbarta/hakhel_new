# Policy for User model - used by admin controllers
class UserPolicy < ApplicationPolicy
  # User management should only be accessible to system admins
  # This policy is for the main User model, not Hke-specific
  
  def index?
    account_user&.admin? || (current_user&.system_admin?)
  end

  def show?
    account_user&.admin? || (current_user&.system_admin?)
  end

  def create?
    account_user&.admin? || (current_user&.system_admin?)
  end

  def update?
    account_user&.admin? || (current_user&.system_admin?)
  end

  def destroy?
    account_user&.admin? || (current_user&.system_admin?)
  end

  class Scope < Scope
    def resolve
      if account_user&.admin? || current_user&.system_admin?
        scope.all
      else
        scope.none
      end
    end

    private

    def current_user
      # Access the actual user from account_user if available
      account_user&.user
    end
  end

  private

  def current_user
    # Access the actual user from account_user if available
    account_user&.user
  end
end
