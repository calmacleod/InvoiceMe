require "test_helper"
require_relative "../test_helpers/invoice_numbering_google"

class ApiV1InvoiceGroupsTest < ActionDispatch::IntegrationTest
  include InvoiceNumberingGoogle

  setup do
    @season = seasons(:current)
    @game, @other_game = %w[EXAMPLE-ONE EXAMPLE-TWO].map do |external_id|
      @season.games.create!(external_id: external_id, date: Date.new(2031, 9, 15))
    end
    @headers = api_headers(users(:one), write_access: true)
  end

  test "groups a finalized invoice and previews a separate payer's invoice without changing the original" do
    league_invoice = invoice("Example League", @game)
    league_invoice.finalize!
    original = league_invoice.attributes.except("updated_at", "invoice_group_id")
    original_lines = league_invoice.line_items.map(&:attributes)

    post api_v1_invoice_groups_path, params: { season_id: @season.id, invoice_id: league_invoice.id }, headers: @headers, as: :json
    assert_response :created
    group = response.parsed_body
    group_id = group.fetch("id")
    assert_equal [ @game.id ], group.fetch("game_ids")
    assert group.fetch("games_locked")
    post api_v1_invoice_groups_path, params: { season_id: @season.id, invoice_id: league_invoice.id }, headers: @headers, as: :json
    assert_response :success
    assert_equal group_id, response.parsed_body.fetch("id")

    patch api_v1_invoice_group_path(group_id), params: { name: "Example group", lock_version: group.fetch("lock_version") }, headers: @headers, as: :json
    assert_response :success
    assert_equal "Example group", response.parsed_body.fetch("name")
    patch api_v1_invoice_group_path(group_id), params: { game_ids: [ @other_game.id ], lock_version: response.parsed_body.fetch("lock_version") }, headers: @headers, as: :json
    assert_response :unprocessable_entity

    post api_v1_drafts_path, params: { season_id: @season.id, invoice_group_id: group_id, data: data.merge(game_ids: [ @other_game.id ]) }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    post api_v1_drafts_path, params: { season_id: @season.id, invoice_group_id: group_id, data: data }, headers: @headers, as: :json
    assert_response :created
    draft = response.parsed_body
    assert_equal group_id, draft.fetch("invoice_group_id")
    post preview_api_v1_draft_path(draft.fetch("id")), params: { lock_version: draft.fetch("lock_version") }, headers: @headers, as: :json
    assert_response :success
    result = response.parsed_body
    assert_equal [ "Draft", 1234, "Example Club", group_id, [ @game.id ] ],
      result.values_at("status", "total_cents", "recipient", "invoice_group_id", "game_ids")
    assert_equal original, league_invoice.reload.attributes.except("updated_at", "invoice_group_id")
    assert_equal original_lines, league_invoice.line_items.map(&:attributes)
    assert_equal [ @game.id ], league_invoice.game_ids

    get api_v1_invoice_group_path(group_id), headers: @headers
    assert_response :success
    assert_equal 3734, response.parsed_body.fetch("total_cents")
    assert_equal [ league_invoice.id, result.fetch("id") ], response.parsed_body.fetch("invoices").pluck("id")
  end

  test "reviews attachment changes and applies them with the currently signed game selection" do
    record = invoice("Example Club", @other_game)
    post api_v1_invoice_groups_path, params: { season_id: @season.id, game_ids: [ @game.id ] }, headers: @headers, as: :json
    assert_response :created
    group = response.parsed_body
    group_id = group.fetch("id")

    get attachment_api_v1_invoice_group_path(group_id), params: { invoice_id: record.id }, headers: @headers
    assert_response :success
    review = response.parsed_body
    assert_equal [ [ @game.id ], [ @other_game.id ], nil ], review.values_at("games_added", "games_removed", "blocked_reason")
    post attach_invoice_api_v1_invoice_group_path(group_id), params: { invoice_id: record.id }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    assert_nil record.reload.invoice_group_id
    post attach_invoice_api_v1_invoice_group_path(group_id), params: { invoice_id: record.id, review_token: review.fetch("token") }, headers: @headers, as: :json
    assert_response :success
    assert_equal [ group_id, [ @game.id ], 2500 ], [ record.reload.invoice_group_id, record.game_ids, record.total_cents ]

    patch api_v1_invoice_group_path(group_id), params: { name: "New name", lock_version: group.fetch("lock_version") }, headers: @headers, as: :json
    assert_response :success
    patch api_v1_invoice_group_path(group_id), params: { name: "Stale name", lock_version: group.fetch("lock_version") }, headers: @headers, as: :json
    assert_response :conflict
  end

  test "keeps group workbenches user scoped and honors read-only keys" do
    draft = users(:one).invoice_drafts.create!(season: @season, client_key: "fictional-group-draft", data: data.merge(game_ids: [ @game.id ]))
    other_headers = api_headers(users(:two), write_access: true)
    read_headers = api_headers(users(:one), write_access: false)
    payload = { season_id: @season.id, draft_id: draft.id }
    post api_v1_invoice_groups_path, params: payload, headers: read_headers, as: :json
    assert_response :forbidden
    post api_v1_invoice_groups_path, params: payload, headers: other_headers, as: :json
    assert_response :not_found

    post api_v1_invoice_groups_path, params: payload, headers: @headers, as: :json
    assert_response :created
    group_id = response.parsed_body.fetch("id")
    assert_equal [ draft.id ], response.parsed_body.fetch("drafts").pluck("id")
    assert_not draft.reload.data.key?("game_ids")
    get api_v1_invoice_group_path(group_id), headers: other_headers
    assert_response :success
    assert_empty response.parsed_body.fetch("drafts")
    get api_v1_invoice_groups_path, params: { season_id: @season.id }, headers: read_headers
    assert_response :success
    assert_equal [ group_id ], response.parsed_body.fetch("data").pluck("id")
  end

  private

  def api_headers(user, write_access:)
    _, token = ApiKey.issue!(user: user, name: "Example group API", write_access: write_access)
    { "Authorization" => "Bearer #{token}" }
  end

  def invoice(recipient, game)
    @season.invoices.create!(number: "EXAMPLE-#{recipient.parameterize}", recipient: recipient, description: "Fictional service",
      issued_on: Date.new(2031, 9, 15), game_ids: [ game.id ], line_items_attributes: [ { description: "Fictional service", quantity: 1, rate: "25.00" } ])
  end

  def data
    { number_suffix: "ExampleClub", recipient: "Example Club", description: "Fictional support", issued_on: "2031-09-15",
      line_items_attributes: [ { key: "fictional", description: "Fictional support", quantity: 1, rate: "12.34" } ] }
  end
end
