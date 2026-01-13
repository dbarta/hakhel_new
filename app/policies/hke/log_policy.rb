module Hke
  class LogPolicy < ApplicationPolicy
    # Logs can be viewed by system admins and community admins
    # Community admins can only view logs for their community
    
    def index?
      user.system_admin? || user.community_admin?
    end

    def show?
      user.system_admin? || (user.community_admin? && same_community?)
    end

    class Scope < Scope
      def resolve
        if user.system_admin?
          scope.all
        elsif user.community_admin?
          # Community admins see only logs for their community
          scope.where(community: user.community)
        else
          scope.none
        end
      end
    end
  end
end

