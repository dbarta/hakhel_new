module Hke
  class UserPolicy < ApplicationPolicy
    def index?
      user.system_admin? || user.community_admin?
    end

    def show?
      user.system_admin? || (user.community_admin? && same_community?(record))
    end

    def create?
      user.system_admin?
    end

    def update?
      user.system_admin? || user == record
    end

    def destroy?
      user.system_admin?
    end

    class Scope < Scope
      def resolve
        if user.system_admin?
          scope.all
        elsif user.community_admin?
          scope.where(community_id: user.community_id)
        else
          scope.none
        end
      end
    end

    private

    def same_community?(record)
      record.community_id == user.community_id
    end
  end
end
