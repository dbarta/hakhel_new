module Hke
  class SelectionPolicy < ApplicationPolicy
    # Selections can be managed by system admins and community admins
    # Community admins can only manage selections in their community
    
    def index?
      user.system_admin? || user.community_admin?
    end

    def show?
      user.system_admin? || (user.community_admin? && same_community?)
    end

    def create?
      user.system_admin? || user.community_admin?
    end

    def update?
      user.system_admin? || (user.community_admin? && same_community?)
    end

    def destroy?
      user.system_admin? || (user.community_admin? && same_community?)
    end

    class Scope < Scope
      def resolve
        if user.system_admin?
          scope.all
        elsif user.community_admin?
          # Community admins see only selections in their community
          scope.where(community: user.community)
        else
          scope.none
        end
      end
    end

    private

    def same_community?
      return false unless user.community_admin? && user.community
      # Check if the selection belongs to the user's community
      # This assumes selections are scoped by community through ActsAsTenant
      record.community == user.community
    end
  end
end
