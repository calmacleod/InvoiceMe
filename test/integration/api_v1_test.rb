require "test_helper"
require_relative "../test_helpers/invoice_numbering_google"

require_relative "../test_helpers/fake_google"

class ApiV1Test < ActionDispatch::IntegrationTest
  include InvoiceNumberingGoogle
  setup do
    @user = users(:one)
    @key, @token = ApiKey.issue!(user: @user, name: "Test", write_access: true)
    @headers = { "Authorization" => "Bearer #{@token}" }
    @season = seasons(:current)
  end

  test "authentication, permissions and revocation" do
    get "/api/v1/seasons"
    assert_response :unauthorized
    get "/api/v1/seasons", headers: @headers
    assert_response :success
    assert @key.reload.last_used_at
    _, read_token = ApiKey.issue!(user: @user, name: "Read only")
    post "/api/v1/contacts", params: { contact: { name: "Fictional" } }, headers: { "Authorization" => "Bearer #{read_token}" }, as: :json
    assert_response :forbidden
    @key.update!(revoked_at: Time.current)
    get "/api/v1/seasons", headers: @headers
    assert_response :unauthorized
  end

  test "contacts and drafts belong to the key user" do
    other_contact = users(:two).contacts.create!(name: "Other")
    get "/api/v1/contacts/#{other_contact.id}", headers: @headers
    assert_response :not_found
    post "/api/v1/contacts", params: { contact: { name: "Fictional Club", email: "office@example.test" } }, headers: @headers, as: :json
    assert_response :created
    post "/api/v1/drafts", params: { season_id: @season.id, data: { recipient: "Fictional Club" } }, headers: @headers, as: :json
    assert_response :created
    id = response.parsed_body.fetch("id")
    version = response.parsed_body.fetch("lock_version")
    patch "/api/v1/drafts/#{id}", params: { lock_version: version, data: { recipient: "Updated" } }, headers: @headers, as: :json
    assert_response :success
    patch "/api/v1/drafts/#{id}", params: { lock_version: version, data: { recipient: "Stale" } }, headers: @headers, as: :json
    assert_response :conflict
    assert_equal "Updated", InvoiceDraft.find(id).data["recipient"]
  end

  test "invoice lifecycle preserves numbering and finalization rules" do
    @season.update!(spreadsheet_id: "fictional-ledger")
    attrs = { number_suffix: "Club", recipient: "Fictional Club", description: "Services", issued_on: "2031-09-15", line_items_attributes: [ { description: "Officials", quantity: 1, rate: "13.37" } ] }
    post "/api/v1/invoices", params: { season_id: @season.id, invoice: attrs }, headers: @headers, as: :json
    assert_response :created
    id = response.parsed_body.fetch("id")
    assert_equal 1337, response.parsed_body.fetch("total_cents")
    invoice = Invoice.find(id)
    invoice.finalize!
    patch "/api/v1/invoices/#{id}", params: { invoice: { recipient: "Changed" } }, headers: @headers, as: :json
    assert_response :conflict
    post "/api/v1/invoices/#{id}/payment", params: { amount: "2.00", received_on: "2031-09-16", method: "Cheque" }, headers: @headers, as: :json
    assert_response :created
    assert_equal 1137, response.parsed_body.fetch("owed_cents")
    post "/api/v1/invoices/#{id}/reopen", headers: @headers
    assert_response :unprocessable_entity
    get "/api/v1/invoices/#{id}/pdf", headers: @headers
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "draft preview creates an invoice and rejects a stale revision" do
    data = { number_suffix: "Example", recipient: "Fictional Club", description: "Services", issued_on: "2031-09-15", line_items_attributes: [ { description: "Officials", quantity: "1", rate: "13.37" } ] }
    post "/api/v1/drafts", params: { season_id: @season.id, data: data }, headers: @headers, as: :json
    assert_response :created
    id = response.parsed_body.fetch("id")
    version = response.parsed_body.fetch("lock_version")
    post "/api/v1/drafts/#{id}/preview", params: { lock_version: version + 1 }, headers: @headers, as: :json
    assert_response :conflict
    assert_equal 0, @season.invoices.count
    post "/api/v1/drafts/#{id}/preview", params: { lock_version: version }, headers: @headers, as: :json
    assert_response :success
    assert_equal 1337, response.parsed_body.fetch("total_cents")
    assert_equal({}, InvoiceDraft.find(id).data)
  end

  test "private breakdowns survive API draft updates and previews and remain user scoped" do
    breakdown = { notes: "Private fictional note", entries: [ { key: "trip", description: "Fictional trip", amount: "20.00" } ] }
    data = { number_suffix: "Example", recipient: "Fictional Club", description: "Services", issued_on: "2031-09-15", line_items_attributes: [ { description: "Travel", quantity: "1", rate: "20.00", amount_only: true, private_breakdown: breakdown } ] }
    post "/api/v1/drafts", params: { season_id: @season.id, data: data }, headers: @headers, as: :json
    assert_response :created
    draft_id = response.parsed_body.fetch("id")
    version = response.parsed_body.fetch("lock_version")
    assert_equal breakdown.deep_stringify_keys, response.parsed_body.dig("data", "line_items_attributes", 0, "private_breakdown")
    patch "/api/v1/drafts/#{draft_id}", params: { lock_version: version, data: data }, headers: @headers, as: :json
    assert_response :success
    post "/api/v1/drafts/#{draft_id}/preview", params: { lock_version: response.parsed_body.fetch("lock_version") }, headers: @headers, as: :json
    assert_response :success
    invoice_id = response.parsed_body.fetch("id")
    assert_equal breakdown.deep_stringify_keys, response.parsed_body.dig("line_items", 0, "private_breakdown")
    _, other_token = ApiKey.issue!(user: users(:two), name: "Other")
    get "/api/v1/invoices/#{invoice_id}", headers: { "Authorization" => "Bearer #{other_token}" }
    assert_response :success
    assert_nil response.parsed_body.dig("line_items", 0, "private_breakdown")
  end

  test "API workbenches preserve a grouped invoice's shared games" do
    game = @season.games.create!(external_id: "EXAMPLE-SHARED", date: Date.new(2031, 9, 15))
    group = InvoiceGroup.start!(season: @season, game_ids: [ game.id ])
    data = { number_suffix: "Example", recipient: "Fictional Club", description: "Services", issued_on: "2031-09-15",
      line_items_attributes: [ { description: "Stick crew", quantity: "1", rate: "20.00" } ] }
    web_draft = @user.invoice_drafts.create!(season: @season, invoice_group: group, client_key: "example-grouped", data: data)
    post "/api/v1/drafts/#{web_draft.id}/preview", params: { lock_version: web_draft.lock_version }, headers: @headers, as: :json
    assert_response :success
    assert_equal group.id, response.parsed_body.fetch("invoice_group_id")
    assert_equal [ game.id ], response.parsed_body.fetch("game_ids")
    invoice = web_draft.reload.invoice
    web_draft.destroy!

    post "/api/v1/drafts", params: { season_id: @season.id, invoice_id: invoice.id, data: { game_ids: [ game.id ] } }, headers: @headers, as: :json
    assert_response :created
    assert_equal group.id, response.parsed_body.fetch("invoice_group_id")
    draft = InvoiceDraft.find(response.parsed_body.fetch("id"))
    patch "/api/v1/drafts/#{draft.id}", params: { lock_version: draft.lock_version, data: { game_ids: [] } }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    assert_equal [ game.id ], invoice.reload.game_ids
  end

  test "import previews and commits only synthetic file data" do
    file = fixture_file_upload("horizon.csv", "text/csv")
    post "/api/v1/games/import", params: { season_id: @season.id, file: file }, headers: @headers
    assert_response :success
    assert_equal false, response.parsed_body.fetch("committed")
    assert_equal 0, @season.games.count
    file = fixture_file_upload("horizon.csv", "text/csv")
    post "/api/v1/games/import", params: { season_id: @season.id, file: file, commit: "true" }, headers: @headers
    assert_response :success
    assert_equal true, response.parsed_body.fetch("committed")
    assert_operator @season.games.count, :>, 0
  end
end
