module Hke
  class SystemPolicy < ApplicationPolicy
    # System preferences should only be accessible to system admins
    
    def index?
      user.system_admin?
    end

    def show?
      user.system_admin?
    end

    def edit?
      user.system_admin?
    end

    def update?
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
