require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "password reset form renders with auth layout and Hebrew email label" do
    I18n.with_locale(:he) do
      get new_user_password_path
      assert_response :success

      assert_select "html[dir=rtl]"
      assert_select "label", text: "אימייל"
      assert_includes response.body, "user[email]"
    end
  end
end
