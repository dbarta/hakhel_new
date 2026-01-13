module Hke
  class CsvImportLogPolicy < ApplicationPolicy
    def create?
      user.community_admin? || user.system_admin?
    end
  end
end










