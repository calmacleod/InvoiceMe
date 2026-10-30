require "test_helper"

class GoogleApiTest < ActiveSupport::TestCase
  setup do
    @api = GoogleApi.allocate
    @api.instance_variable_set(:@access_token, "fictional-access-token")
  end

  test "ledger reads report transient errors for the job to retry without sleeping" do
    %w[429 500 502 503 504].each do |code|
      with_responses(response(code)) do |requests, delays|
        assert_raises(GoogleApi::TransientError) { @api.values("example-sheet", "'Example'!A3:I3") }
        assert_equal [ "GET" ], requests.map(&:method)
        assert_empty delays
      end
    end
  end

  test "rate limited ledger writes can be retried with the same fixed range and values" do
    with_responses(response("429"), response("200", updatedCells: 9)) do |requests, delays|
      values = [ [ "2026_Example", "2026-09-15", "Fees" ] ]
      assert_raises(GoogleApi::TransientError) { @api.write_values("example-sheet", "'Example'!A3:I3", values) }
      @api.write_values("example-sheet", "'Example'!A3:I3", values)
      assert_equal %w[PUT PUT], requests.map(&:method)
      assert_equal requests.first.uri, requests.last.uri
      assert_equal requests.first.body, requests.last.body
      assert_empty delays
    end
  end

  test "exhausted server errors identify the failed step without blaming permissions or disclosing request data" do
    failure = { error: { errors: [ { reason: "internalError" } ], message: "Private fictional invoice content" } }
    with_responses(response("500", failure)) do |requests, delays|
      error = assert_raises(GoogleApi::TransientError) { @api.values("example-sheet", "'Example'!A3:I3") }
      assert_includes error.message, "HTTP 500 while reading the Google Sheets ledger (internalError)"
      assert_includes error.message, "Try syncing again shortly"
      assert_not_includes error.message, "permissions"
      assert_not_includes error.message, "Private fictional invoice content"
      assert_equal 1, requests.size
      assert_empty delays
    end
  end

  test "Google's 403 rate limits retry while genuine permission errors do not" do
    %w[rateLimitExceeded userRateLimitExceeded].each do |reason|
      with_responses(response("403", error: { errors: [ { reason: reason } ] })) do
        error = assert_raises(GoogleApi::TransientError) { @api.values("example-sheet", "'Example'!A3:I3") }
        assert_includes error.message, "Google is limiting requests"
        assert_not_includes error.message, "permissions"
      end
    end
  end

  test "temporary authorization errors retry without asking the user to reconnect" do
    with_responses(response("503")) do
      error = assert_raises(GoogleApi::TransientError) { GoogleApi.token(grant_type: "refresh_token", refresh_token: "fictional-token") }
      assert_not_includes error.message, "Reconnect"
    end
    with_responses(response("400", error: "invalid_grant")) do
      error = assert_raises(GoogleApi::Error) { GoogleApi.token(grant_type: "refresh_token", refresh_token: "fictional-token") }
      assert_not_kind_of GoogleApi::TransientError, error
      assert_includes error.message, "Reconnect"
    end
  end

  test "interrupted network requests become retryable without exposing connection details" do
    [ Net::ReadTimeout.new("Fictional private details"), Errno::ECONNRESET.new, OpenSSL::SSL::SSLError.new ].each do |failure|
      with_responses(failure) do
        error = assert_raises(GoogleApi::TransientError) { @api.values("example-sheet", "'Example'!A3:I3") }
        assert_includes error.message, "connection to Google was interrupted"
        assert_not_includes error.message, "Fictional private details"
      end
    end
  end

  test "permission failures stop immediately with configuration guidance" do
    with_responses(response("403", error: { errors: [ { reason: "insufficientPermissions" } ] })) do |requests, delays|
      error = assert_raises(GoogleApi::Error) { @api.values("example-sheet", "'Example'!A3:I3") }
      assert_includes error.message, "insufficientPermissions"
      assert_includes error.message, "Check folder/sheet permissions"
      assert_equal 1, requests.size
      assert_empty delays
    end
  end

  test "ambiguous document creation errors are recovered by lookup on the next sync" do
    with_responses(
      response("200", files: []),
      response("500", error: { errors: [ { reason: "internalError" } ] }),
      response("200", files: [ { id: "existing-example-doc" } ])
    ) do |requests, delays|
      attrs = { name: "2026_Example", folder: "example-folder", mime: "application/vnd.oasis.opendocument.text", target_mime: "application/vnd.google-apps.document", bytes: "fictional-document", key: "example-key" }
      error = assert_raises(GoogleApi::Error) { @api.upload(**attrs) }
      assert_includes error.message, "HTTP 500 while creating the Google Doc (internalError)"
      assert_equal %w[GET POST], requests.map(&:method)
      assert_empty delays

      assert_equal "existing-example-doc", @api.upload(**attrs)
      assert_equal %w[GET POST GET], requests.map(&:method)
      assert_equal requests.first.uri, requests.last.uri
    end
  end

  test "non JSON Google failures still give a useful PDF export error" do
    failure = response("502")
    failure.body = "<html>Private fictional proxy response</html>"
    with_responses(response("200", files: []), failure) do |requests, delays|
      error = assert_raises(GoogleApi::Error) do
        @api.upload(name: "2026_Example.pdf", folder: "example-folder", mime: "application/pdf", bytes: "%PDF-fictional", key: "example-pdf-key")
      end
      assert_includes error.message, "HTTP 502 while uploading the PDF"
      assert_includes error.message, "Try syncing again shortly"
      assert_not_includes error.message, "Private fictional proxy response"
      assert_equal %w[GET POST], requests.map(&:method)
      assert_empty delays
    end
  end

  test "unexpected error payload shapes and unsafe diagnostic codes are ignored" do
    [ [], { error: "unexpected" }, { error: { errors: [ "unexpected" ] } }, { error: { errors: [ { reason: "Private fictional information!" } ] } } ].each do |payload|
      with_responses(response("400", payload)) do
        error = assert_raises(GoogleApi::Error) { @api.values("example-sheet", "'Example'!A3:I3") }
        assert_includes error.message, "HTTP 400 while reading the Google Sheets ledger."
        assert_not_includes error.message, "Private fictional information"
      end
    end
  end

  private

  def response(code, payload = {})
    Net::HTTPResponse::CODE_TO_OBJ.fetch(code).new("1.1", code, "Example").tap do |response|
      response.body = JSON.generate(payload)
      response.instance_variable_set(:@read, true)
    end
  end

  def with_responses(*responses)
    requests, delays = [], []
    http = Object.new
    http.define_singleton_method(:request) do |request|
      requests << request
      raise "Unexpected Google request" if responses.empty?
      response = responses.shift
      raise response if response.is_a?(Exception)
      response
    end
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*args, **options, &block| block.call(http) }
    @api.define_singleton_method(:sleep) { |duration| delays << duration }
    yield requests, delays
    assert_empty responses
  ensure
    Net::HTTP.define_singleton_method(:start, original_start) if original_start
  end
end
