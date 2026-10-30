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
  test "revised documents replace the existing Drive file without moving it" do
    %w[application/vnd.google-apps.document application/pdf].each do |mime|
      with_responses(response("200", id: "existing-example-file")) do |requests, _|
        id = @api.upload(name: "2031_Example", folder: "example-folder", mime: "application/vnd.oasis.opendocument.text", target_mime: mime,
          bytes: "revised-fictional-document", key: "example-key", file_id: "existing-example-file", replace: true)
        assert_equal "existing-example-file", id
        assert_equal [ "PATCH" ], requests.map(&:method)
        assert_equal "/upload/drive/v3/files/existing-example-file", requests.first.uri.path
        assert_includes requests.first.body, "revised-fictional-document"
        assert_includes requests.first.body, %Q("mimeType":"#{mime}")
        assert_not_includes requests.first.body, '"parents"'
      end
    end
  end
  test "reopening after an ambiguous creation replaces the recovered file contents" do
    with_responses(response("200", files: [ { id: "recovered-example-doc" } ]), response("200", id: "recovered-example-doc")) do |requests, _|
      id = @api.upload(name: "2031_Example", folder: "example-folder", mime: "application/vnd.oasis.opendocument.text", target_mime: "application/vnd.google-apps.document",
        bytes: "revised-fictional-document", key: "example-key", replace: true)
      assert_equal "recovered-example-doc", id
      assert_equal %w[GET PATCH], requests.map(&:method)
      assert_includes requests.last.body, "revised-fictional-document"
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

  test "ledger metadata and cell reads retain native table boundaries formulas and date formats" do
    sheet = { properties: { sheetId: 123, title: "Example ledger", gridProperties: { rowCount: 100 } }, tables: [ { tableId: "example-table", range: { startRowIndex: 1, endRowIndex: 20 } } ] }
    cell = { userEnteredValue: { formulaValue: "=E4-F4" }, effectiveValue: { numberValue: 0 }, userEnteredFormat: { numberFormat: { type: "CURRENCY" } } }
    with_responses(response("200", sheets: [ sheet ]), response("200", sheets: [ { data: [ { rowData: [ { values: [ cell ] } ] } ] } ])) do |requests, _|
      assert_equal "example-table", @api.sheet_metadata("example-sheet", "Example ledger").dig("tables", 0, "tableId")
      assert_equal "=E4-F4", @api.ledger_cells("example-sheet", "'Example ledger'!A4:L4").first.dig("userEnteredValue", "formulaValue")
      query = URI.decode_www_form(requests.last.uri.query).to_h
      assert_equal "'Example ledger'!A4:L4", query["ranges"]
      assert_includes query["fields"], "userEnteredFormat(numberFormat)"
    end
  end

  test "ledger relocation sends both value-only edits in one batch" do
    range = { sheetId: 123, startRowIndex: 3, endRowIndex: 4, startColumnIndex: 0, endColumnIndex: 9 }
    requests = [
      { updateCells: { range: range, rows: [ { values: [ { userEnteredValue: { stringValue: "2031_Example" } } ] } ], fields: "userEnteredValue" } },
      { updateCells: { range: range.merge(startRowIndex: 30, endRowIndex: 31), rows: [ { values: Array.new(9) { {} } } ], fields: "userEnteredValue" } }
    ]
    with_responses(response("200", replies: [ {}, {} ])) do |sent, _|
      @api.batch_update("example-sheet", requests)
      assert_equal [ "POST" ], sent.map(&:method)
      assert_equal "/v4/spreadsheets/example-sheet:batchUpdate", sent.first.uri.path
      body = JSON.parse(sent.first.body)
      assert_equal 2, body.fetch("requests").size
      assert body.fetch("requests").all? { |request| request.dig("updateCells", "fields") == "userEnteredValue" }
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
