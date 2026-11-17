require "test_helper"

class HorizonClientTest < ActiveSupport::TestCase
  setup do
    @client = Horizon::Client.new(app_id: "fictional-id", app_key: "fictional-key", access_token: "fictional-token")
  end

  test "requests use documented headers JSON parameters and retain the full envelope" do
    payload = { status: 200, current_page: 1, total_pages: 2, result: [ { event_id: "fictional" } ] }
    with_response(response("200", payload)) do |requests|
      result = @client.request(:get, "schedule", params: { start_date: "2031-01-01", team_id: [ "one", "two" ] })
      request = requests.first
      assert_equal "GET", request.method
      assert_equal "https://api-2445581139242.apicast.io/api/v1/schedule", request.uri.to_s
      assert_equal "fictional-id", request["app_id"]
      assert_equal "fictional-key", request["app_key"]
      assert_equal "fictional-token", request["access_token"]
      assert_equal({ "start_date" => "2031-01-01", "team_id" => [ "one", "two" ] }, JSON.parse(request.body))
      assert_equal 2, result["total_pages"]
    end
  end

  test "authorization calls do not require an access token" do
    client = Horizon::Client.new(app_id: "id", app_key: "key")
    with_response(response("200", login_uri: "https://example.test"), response("200", access_token: "token")) do |requests|
      client.request_code(scope: [ "read_organization" ], callback_uri: "https://example.test/callback")
      client.request_token(authorization_code: "fictional-code")
      assert_equal [ "/api/v1/oauth2/requestCode", "/api/v1/oauth2/requestToken" ], requests.map { |r| r.uri.path }
      assert_equal({ "authorization_code" => "fictional-code" }, JSON.parse(requests.last.body))
      assert_nil requests.first["access_token"]
      assert_raises(Horizon::Client::ConfigurationError) { client.request(:get, "schedule") }
    end
  end

  test "path segments cannot change the destination and unsupported methods are rejected" do
    with_response(response("200", result: [])) do |requests|
      @client.request(:delete, "team", "fictional/id ?")
      assert_equal "/api/v1/team/fictional%2Fid%20%3F", requests.first.uri.path
    end
    assert_raises(ArgumentError) { @client.request(:get, "..") }
    assert_raises(ArgumentError) { @client.request(:patch, "team") }
  end

  test "errors are classified without exposing private response data and never retried" do
    { "403" => Horizon::Client::AuthenticationError, "409" => Horizon::Client::Error, "429" => Horizon::Client::RateLimitError, "503" => Horizon::Client::TransientError }.each do |code, error_class|
      with_response(response(code, error: "fictional private data")) do |requests|
        error = assert_raises(error_class) { @client.request(:post, "schedule", params: { name: "private" }) }
        assert_equal code.to_i, error.status
        assert_not_includes error.message, "private"
        assert_equal 1, requests.length
      end
    end
  end

  test "malformed and error envelopes and network failures are safe" do
    [ response("200", error: "private details"), response("200", [ 1 ]), response("200", "not json") ].each do |reply|
      with_response(reply) do
        error = assert_raises(Horizon::Client::Error) { @client.request(:get, "team") }
        assert_not_includes error.message, "private"
      end
    end
    with_response(Net::ReadTimeout.new("private")) do
      error = assert_raises(Horizon::Client::TransientError) { @client.request(:get, "team") }
      assert_not_includes error.message, "private"
    end
  end

  private

  def response(code, body = {})
    result = Net::HTTPResponse::CODE_TO_OBJ.fetch(code).new("1.1", code, "test")
    result.body = body.is_a?(String) ? body : JSON.generate(body)
    result.instance_variable_set(:@read, true)
    result
  end

  def with_response(*responses)
    requests = []
    http = Object.new
    http.define_singleton_method(:request) do |request|
      requests << request
      result = responses.shift || raise("Unexpected request")
      raise result if result.is_a?(Exception)
      result
    end
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*args, **options, &block| block.call(http) }
    yield requests
    assert_empty responses
  ensure
    Net::HTTP.define_singleton_method(:start, original_start) if original_start
  end
end
