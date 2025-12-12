class Users::PasswordsController < Devise::PasswordsController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_user_session_path, alert: I18n.t("try_again_later") }
end
