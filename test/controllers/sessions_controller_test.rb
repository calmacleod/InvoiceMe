require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end

class AuthenticationRevocationTest < ActionDispatch::IntegrationTest
  test "a revoked database session cannot authenticate with its old signed cookie" do
    sign_in_as(users(:one))
    Current.session.destroy!
    Current.reset
    get root_path
    assert_redirected_to new_session_path
  end

  test "valid login returns to the originally requested page" do
    get games_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    assert_redirected_to games_url
  end
end
