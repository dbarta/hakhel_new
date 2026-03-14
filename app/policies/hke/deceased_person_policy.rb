module Hke
  class DeceasedPersonPolicy < ApplicationPolicy
    # Supports two pundit_user types:
    #   AccountUser   — admin context (system_admin / community_admin)
    #   ContactPerson — portal context (self-service, scoped to own relations)

    def index?
      admin? && (user.system_admin? || user.community_admin?)
    end

    def show?
      portal? ? related_contact? : (user.system_admin? || (user.community_admin? && same_community?))
    end

    def create?
      admin? && (user.system_admin? || user.community_admin?)
    end

    def update?
      portal? ? related_contact? : (user.system_admin? || (user.community_admin? && same_community?))
    end

    def destroy?
      portal? ? related_contact? : (user.system_admin? || (user.community_admin? && same_community?))
    end

    class Scope < Scope
      def resolve
        if user.is_a?(Hke::ContactPerson)
          scope.joins(:relations).where(hke_relations: { contact_person_id: user.id })
        elsif user.system_admin?
          scope.all
        elsif user.community_admin?
          scope.where(community: user.community)
        else
          scope.none
        end
      end
    end

    private

    def admin?
      user.is_a?(AccountUser)
    end

    def portal?
      user.is_a?(Hke::ContactPerson)
    end

    def related_contact?
      user.relations.exists?(deceased_person_id: record.id)
    end

    def same_community?
      user.community_admin? && user.community && record.community == user.community
    end
  end
end
