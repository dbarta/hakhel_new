module Hke
  class ApplicationPolicy
    attr_reader :user, :record

    def initialize(user, record)
      raise Pundit::NotAuthorizedError, "must be logged in" unless user
      @user = user
      @record = record
    end

    def index?
      user.system_admin? || user.community_admin?
    end

    def show?
      user.system_admin? || user.community_admin?
    end

    def create?
      user.system_admin? || user.community_admin?
    end

    def new?
      create?
    end

    def update?
      user.system_admin? || user.community_admin?
    end

    def edit?
      update?
    end

    def destroy?
      user.system_admin?  # Only system admins can delete by default
    end

    class Scope
      def initialize(user, scope)
        raise Pundit::NotAuthorizedError, "must be logged in" unless user
        @user = user
        @scope = scope
      end

      def resolve
        if user.system_admin?
          scope.all  # System admin sees everything
        else
          scope.none  # Override in specific policies
        end
      end

      private

      attr_reader :user, :scope
    end
  end
end
