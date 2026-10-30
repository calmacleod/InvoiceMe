require "test_helper"

class GameBulkActionsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    post select_year_path, params: { id: @season.id }
    @games = 3.times.map { |index| @season.games.create!(external_id: "EXAMPLE-BULK-#{index}", date: "2031-09-15") }
  end

  test "marking and clearing manual status keeps financial records and real invoice links unchanged" do
    invoice = @season.invoices.create!(number: "EXAMPLE-BULK-INVOICE", recipient: "Example Club", description: "Example fees", issued_on: "2031-09-15", line_items_attributes: [ { description: "Example", quantity: 1, rate: "13.37" } ], game_ids: [ @games.first.id ])
    assert_no_difference [ "Invoice.count", "InvoiceGame.count", "LineItem.count", "Payment.count" ] do
      patch invoicing_status_games_path, params: { game_ids: [ @games[0].id, @games[1].id, @games[1].id ], already_invoiced: true }, as: :json
    end
    assert_response :see_other
    assert_equal [ @games[0].id, @games[1].id ].sort, @season.games.where(already_invoiced: true).ids.sort
    search = ->(status) { GameSearch.new(@season.games, { "link_status" => status }, user: users(:one)).results.ids.sort }
    assert_equal [ @games[0].id, @games[1].id ].sort, search.call("invoiced")
    assert_equal [ @games[2].id ], search.call("unlinked")
    patch invoicing_status_games_path, params: { game_ids: @games.first(2).map(&:id), already_invoiced: false }, as: :json
    assert_response :see_other
    assert_empty @season.games.where(already_invoiced: true)
    assert_equal [ @games.first.id ], search.call("invoiced")
    assert_equal [ @games.first.id ], invoice.reload.game_ids
    assert_equal 1337, invoice.total_cents
  end

  test "bulk writes reject another year's games malformed selections and unauthenticated requests" do
    other = Season.create!(year: 2032, sheet_name: "Example", issuer: @season.issuer)
    foreign = other.games.create!(external_id: "EXAMPLE-FOREIGN-BULK", date: "2032-09-15")
    patch invoicing_status_games_path, params: { game_ids: [ @games.first.id, foreign.id ], already_invoiced: true }, as: :json
    assert_response :not_found
    assert_not @games.first.reload.already_invoiced
    assert_not foreign.reload.already_invoiced
    [ [], [ "#{@games.first.id}invalid" ] ].each do |ids|
      patch invoicing_status_games_path, params: { game_ids: ids, already_invoiced: true }, as: :json
      assert_response :bad_request
    end
    patch invoicing_status_games_path, params: { game_ids: @games.map(&:id), already_invoiced: "invalid" }, as: :json
    assert_response :bad_request
    sign_out
    patch invoicing_status_games_path, params: { game_ids: @games.map(&:id), already_invoiced: true }, as: :json
    assert_redirected_to new_session_path
    assert_empty @season.games.where(already_invoiced: true)
  end

  test "select all uses saved filters across every page and marked summaries reach the invoice selector" do
    matches = 30.times.map { |index| @season.games.create!(external_id: "EXAMPLE-MATCH-#{index}", code: "EXAMPLE-MATCH", date: "2031-09-15") }
    patch filters_games_path, params: { code: [ "EXAMPLE-MATCH" ] }
    get games_path, headers: inertia_headers
    assert_equal 25, response.parsed_body.dig("props", "games").size
    assert_not response.parsed_body["props"].key?("matching_game_ids")
    get games_path, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "games/Index", "X-Inertia-Partial-Data" => "matching_game_ids")
    assert_equal matches.map(&:id).sort, response.parsed_body.dig("props", "matching_game_ids").sort
    assert_not response.parsed_body["props"].key?("games")
    patch invoicing_status_games_path, params: { game_ids: matches.map(&:id), already_invoiced: true }, as: :json
    assert_equal 30, @season.games.where(already_invoiced: true).count
    assert_not @games.any? { |game| game.reload.already_invoiced }
    get new_invoice_path, params: { game_filters: { link_status: "invoiced" } }, headers: inertia_headers
    assert_equal 30, response.parsed_body.dig("props", "game_options", "pagination", "total")
    assert response.parsed_body.dig("props", "game_options", "games").all? { |game| game["already_invoiced"] }
  end

  private
  def inertia_headers = { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
end
