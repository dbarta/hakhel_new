module Hke
  class CommunityPolicy < ApplicationPolicy
    # Communities can be managed by system admins and community admins
    # Community admins can only see/edit their own community
    
    def index?
      user.system_admin? || user.community_admin?
    end

    def show?
      user.system_admin? || (user.community_admin? && user.community == record)
    end

    def create?
      user.system_admin?  # Only system admins can create communities
    end

    def update?
      user.system_admin? || (user.community_admin? && user.community == record)
    end

    def destroy?
      user.system_admin?  # Only system admins can delete communities
    end

    class Scope < Scope
      def resolve
        if user.system_admin?
          scope.all
        elsif user.community_admin?
          scope.where(id: user.community_id)
        else
          scope.none
        end
      end
    end
  end
end
