module Hke
  class UserPolicy < ApplicationPolicy
    # User management in Hke admin should only be accessible to system admins
    
    def index?
      user.system_admin?
    end

    def show?
      user.system_admin?
    end

    def create?
      user.system_admin?
    end

    def update?
      user.system_admin?
    end

    def destroy?
      user.system_admin?
    end

    class Scope < Scope
      def resolve
        if user.system_admin?
          scope.all
        else
          scope.none
        end
      end
    end
  end
end
