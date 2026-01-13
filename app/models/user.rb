class User < ApplicationRecord
  include Accounts, Agreements, Authenticatable, Mentions, Notifiable, Profile, Searchable, Theme

  # HKE roles and community association
  ROLES = [:system_admin, :community_admin, :community_user]
  belongs_to :community, class_name: "Hke::Community", optional: true
  before_validation { self.roles ||= {} }

  validate :must_have_at_least_one_role

  scope :system_admin, -> { where("roles @> ?", {system_admin: true}.to_json) }
  scope :community_admin, -> { where("roles @> ?", {community_admin: true}.to_json) }
  scope :community_user, -> { where("roles @> ?", {community_user: true}.to_json) }

  def must_have_at_least_one_role
    return if roles.blank? && admin? # Allow old-style admin users for backward compatibility
    return if roles.is_a?(Hash) && roles.values.any?
    errors.add(:roles, "User must have at least one role assigned")
  end

  # Methods for search_results partial
  def role_summary
    roles_list = []
    roles_list << "מנהל מערכת" if system_admin?
    roles_list << "מנהל קהילה" if community_admin?
    roles_list << "משתמש קהילה" if community_user?
    roles_list.empty? ? "אין תפקידים" : roles_list.join(", ")
  end

  def community_name
    community&.name || "None"
  end

  # Role-based helper methods
  def can_access_system_admin? = system_admin?

  def can_access_community_admin? = system_admin? || community_admin?

  def can_access_community_user? = system_admin? || community_admin? || community_user?

  # For backward compatibility during transition
  def admin?
    super || system_admin?
  end

  ROLES.each do |role|
    define_method("#{role}?") do
      roles.is_a?(Hash) && (roles[role.to_s] || roles[role])
    end
  end
end
