module Hke
  class NotSentMessagePolicy < ApplicationPolicy
    def index?
      user.community_admin? || user.system_admin?
    end

    def show?
      user.community_admin? || user.system_admin?
    end

    def create?
      false
    end

    def update?
      false
    end

    def destroy?
      false
    end

    class Scope < Scope
      def resolve
        if user.system_admin?
          scope.all
        elsif user.community_admin?
          scope.where(community: user.community)
        else
          scope.none
        end
      end
    end
  end
end

