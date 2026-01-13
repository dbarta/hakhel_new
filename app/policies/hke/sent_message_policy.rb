module Hke
  class SentMessagePolicy < ApplicationPolicy
    def index?
      user.community_admin? || user.system_admin?
    end

    def show?
      user.community_admin? || user.system_admin?
    end

    def create?
      false # Sent messages are created by the system
    end

    def update?
      false # Sent messages are not editable
    end

    def destroy?
      false # Sent messages are not deletable
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
