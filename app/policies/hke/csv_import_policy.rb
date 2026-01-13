module Hke
  class CsvImportPolicy < ApplicationPolicy
    def index?
      user.community_admin? || user.system_admin?
    end

    def show?
      user.community_admin? || user.system_admin?
    end

    def new?
      user.community_admin? || user.system_admin?
    end

    def create?
      user.community_admin? || user.system_admin?
    end

    def update?
      user.community_admin? || user.system_admin?
    end

    def destroy?
      user.community_admin? || user.system_admin?
    end

    def destroy_all?
      user.community_admin? || user.system_admin?
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
