module Hke
  class MessageManagementPolicy < ApplicationPolicy
    def index?
      user.community_admin? || user.system_admin?
    end

    def show?
      user.community_admin? || user.system_admin?
    end
  end
end
