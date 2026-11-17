require "test_helper"

class HorizonAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    @old_env = ENV.to_h.slice("HORIZON_APP_ID", "HORIZON_APP_KEY", "APP_URL")
    ENV["HORIZON_APP_ID"] = "fictional-id"
    ENV["HORIZON_APP_KEY"] = "fictional-key"
    ENV["APP_URL"] = "https://example.test"
  end

  teardown do
    %w[HORIZON_APP_ID HORIZON_APP_KEY APP_URL].each { |key| @old_env.key?(key) ? ENV[key] = @old_env[key] : ENV.delete(key) }
  end

  test "authorization binds the callback to the session and encrypts multiple organization codes" do
    with_horizon_responses(reply(login_uri: "https://www.horizonwebref.com/fictional-login")) do |requests|
      post "/horizon/connect", headers: { "X-Inertia" => "true" }
      assert_response :conflict
      assert_equal "https://www.horizonwebref.com/fictional-login", response.headers["X-Inertia-Location"]
      payload = JSON.parse(requests.first.body)
      assert_equal [ "read_organization" ], payload["scope"]
      path = URI(payload.fetch("callback_uri")).path
      get path, params: { authorization_codes: "fictional-code-one,fictional-code-two" }
      assert_redirected_to edit_season_path(@season)
      assert_equal 2, HorizonConnection.count
      assert_equal %w[fictional-code-one fictional-code-two], HorizonConnection.order(:id).map(&:authorization_code)
      raw = HorizonConnection.connection.select_values("SELECT authorization_code FROM horizon_connections")
      assert raw.none? { |value| value.include?("fictional-code") }
      get path, params: { authorization_codes: "fictional-replay" }
      assert_equal 2, HorizonConnection.count
      assert_match(/expired/, flash[:alert])
    end
  end

  test "callback rejects unbound state and never overwrites an existing connection" do
    get "/horizon/callback/wrong", params: { authorization_codes: "fictional-code" }
    assert_equal 0, HorizonConnection.count
    assert_match(/expired/, flash[:alert])
    HorizonConnection.create!(authorization_code: "existing")
    post "/horizon/connect"
    assert_match(/Disconnect/, flash[:alert])
    assert_equal 1, HorizonConnection.count
  end

  test "untrusted login addresses cannot receive redirects" do
    with_horizon_responses(reply(login_uri: "https://horizonwebref.com.example.test/steal")) do
      post "/horizon/connect"
      assert_redirected_to edit_season_path(@season)
      assert_match(/invalid sign-in/, flash[:alert])
    end
  end

  test "read test reuses encrypted unexpired token without repeating exchange" do
    connection = HorizonConnection.create!(authorization_code: "fictional-code")
    expiry = 20.minutes.from_now.to_i
    with_horizon_responses(reply(access_token: "fictional-token", token_expires: expiry, organization: [ { name: "Fictional association" } ]), reply(result: [ { event_id: "fictional" } ]), reply(result: [])) do |requests|
      2.times { post test_horizon_path(connection) }
      assert_equal %w[POST GET GET], requests.map(&:method)
      assert_equal "Fictional association", connection.reload.organization_name
      assert_equal "fictional-token", connection.access_token
      stored = HorizonConnection.connection.select_value("SELECT access_token FROM horizon_connections LIMIT 1")
      assert_not_includes stored, "fictional-token"
      assert_match(/read access succeeded/, flash[:notice])
      assert_equal 0, Game.count
    end
  end

  test "settings never include authorization codes or tokens and disconnect is local" do
    HorizonConnection.create!(authorization_code: "fictional-secret", access_token: "fictional-token")
    get edit_season_path(@season)
    assert_response :success
    assert_not_includes response.body, "fictional-secret"
    assert_not_includes response.body, "fictional-token"
    delete "/horizon/disconnect"
    assert_equal 0, HorizonConnection.count
  end

  private

  def reply(payload)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      response.body = JSON.generate(payload)
      response.instance_variable_set(:@read, true)
    end
  end

  def with_horizon_responses(*responses)
    requests = []
    http = Object.new
    http.define_singleton_method(:request) { |request| requests << request; responses.shift || raise("Unexpected request") }
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*args, **options, &block| block.call(http) }
    yield requests
    assert_empty responses
  ensure
    Net::HTTP.define_singleton_method(:start, original) if original
  end
end
