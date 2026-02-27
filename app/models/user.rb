class User < ApplicationRecord
  include Accounts, Agreements, Authenticatable, Mentions, Notifiable, Profile, Searchable, Theme
  include Hke::LogModelEvents

  # HKE roles and community association
  belongs_to :community, class_name: "Hke::Community", optional: true

  before_save :clear_community_unless_needed
  validate :must_have_at_least_one_role

  scope :system_admin, -> { where(system_admin: true) }
  scope :community_admin, -> { where(community_admin: true) }
  scope :community_user, -> { where(community_user: true) }

  def must_have_at_least_one_role
    return if admin? # Allow old-style admin users for backward compatibility
    unless system_admin? || community_admin? || community_user?
      errors.add(:base, :must_have_at_least_one_role)
    end
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

  private

  SENSITIVE_USER_FIELDS = %w[encrypted_password reset_password_token remember_token
    invitation_token confirmation_token unlock_token otp_secret].freeze

  def log_model_event(event_type, data)
    filtered = data.except(*SENSITIVE_USER_FIELDS)
    Hke::Logger.log(
      event_type: event_type,
      entity: self,
      community_id: community_id,
      details: filtered
    )
  end

  def clear_community_unless_needed
    self.community_id = nil unless community_admin? || community_user?
  end
end
