require "test_helper"

class GameBrowserTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    post select_year_path, params: { id: @season.id }
    @game = @season.games.create!(external_id: "EXAMPLE-FILTER-1", home_team: "Fictional Alpha", away_team: "Fictional Bravo", code: "EXAMPLE-CODE", date: "2031-02-17", location: "Fictional Field", fees_cents: 3559,
      officials: [ { name: "Fictional Rowan", position: "Referee", fee_cents: 1337 }, { name: "Fictional Avery", position: "Umpire", fee_cents: 2222 } ], source: [ { "Example private source" => "Only on demand" } ])
    @season.games.create!(external_id: "EXAMPLE-FILTER-2", home_team: "Fictional Bravo", away_team: "Fictional Alpha", code: "OTHER", date: "2031-02-18")
    @draft = InvoiceDraft.create!(user: users(:one), season: @season, client_key: "example-browser", data: { "recipient" => "Example draft", "game_ids" => [ @game.id ] })
    InvoiceDraft.create!(user: users(:two), season: @season, client_key: "example-other-browser", data: { "recipient" => "Private other title", "game_ids" => [ @game.id ] })
  end

  test "both pages use the same combined filters without source rows in summaries" do
    filters = { home_team: "alpha", away_team: "bravo", code: "code", official: "rowan", date_from: "2031-02-17", date_to: "2031-02-17", link_status: "workbench" }
    get games_path, params: filters, headers: inertia_headers
    assert_equal [ @game.id ], response.parsed_body.dig("props", "games").map { |game| game["id"] }
    summary = response.parsed_body.dig("props", "games", 0)
    assert_equal [ @draft.id ], summary["workbenches"].map { |draft| draft["id"] }
    refute_includes response.body, "Private other title"
    refute_includes response.body, "Fictional Rowan"
    refute_includes response.body, "Only on demand"
    get new_invoice_path, params: { game_filters: filters }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "game_options")
    assert_equal [ @game.id ], response.parsed_body.dig("props", "game_options", "games").map { |game| game["id"] }
    assert_equal "alpha", response.parsed_body.dig("props", "game_options", "filters", "home_team")
    refute response.parsed_body["props"].key?("invoice")
    refute_includes response.body, "Only on demand"
  end

  test "both pages can fetch individual fee breakdowns and reject games in another year" do
    [ [ games_path, "games/Index" ], [ new_invoice_path, "invoices/Edit" ] ].each do |path, component|
      get path, params: { detail_id: @game.id }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => component, "X-Inertia-Partial-Data" => "game_detail")
      assert_equal [ 1337, 2222 ], response.parsed_body.dig("props", "game_detail", "officials").map { |official| official["fee_cents"] }
      refute response.parsed_body["props"].key?("games")
    end
    other = Season.create!(year: 2032, sheet_name: "Example", issuer: @season.issuer)
    game = other.games.create!(external_id: "EXAMPLE-OTHER-YEAR", date: "2032-02-17")
    get new_invoice_path, params: { detail_id: game.id }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "game_detail")
    assert_response :not_found
  end

  test "array selections and all master choices reach both game browsers" do
    28.times { |index| @season.games.create!(external_id: "EXAMPLE-MULTI-#{index}", code: "EXAMPLE-CHOICE-#{index}", home_team: "Fictional Third", away_team: "Fictional Fourth", date: "2031-03-01") }
    filters = { code: [ "EXAMPLE-CODE", "OTHER" ], home_team: [ "Fictional Alpha", "Fictional Bravo" ], away_team: [ "Fictional Alpha", "Fictional Bravo" ] }
    get games_path, params: filters, headers: inertia_headers
    assert_equal 2, response.parsed_body.dig("props", "pagination", "total")
    assert_equal filters[:code], response.parsed_body.dig("props", "filters", "code")
    assert_includes response.parsed_body.dig("props", "filter_choices", "code"), "EXAMPLE-CHOICE-27"
    get new_invoice_path, params: { game_filters: filters }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "game_options")
    assert_equal 2, response.parsed_body.dig("props", "game_options", "pagination", "total")
    assert_equal filters[:home_team], response.parsed_body.dig("props", "game_options", "filters", "home_team")
    assert_includes response.parsed_body.dig("props", "game_options", "filter_choices", "code"), "EXAMPLE-CHOICE-27"
  end

  test "master and invoice pagination retain every applied filter" do
    30.times { |i| @season.games.create!(external_id: "EXAMPLE-PAGE-#{i}", home_team: "Fictional Alpha", away_team: "Fictional Bravo", code: "EXAMPLE-CODE", date: "2031-02-17") }
    filters = { home_team: "alpha", away_team: "bravo", code: "example-code", date_from: "2031-02-17", date_to: "2031-02-17" }
    get games_path, params: filters.merge(page: 2), headers: inertia_headers
    assert_equal 31, response.parsed_body.dig("props", "pagination", "total")
    assert_equal 6, response.parsed_body.dig("props", "games").size
    assert_equal "alpha", response.parsed_body.dig("props", "filters", "home_team")
    get new_invoice_path, params: { game_filters: filters, game_page: 2 }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "game_options")
    assert_equal 31, response.parsed_body.dig("props", "game_options", "pagination", "total")
    assert_equal 6, response.parsed_body.dig("props", "game_options", "games").size
    assert_equal "example-code", response.parsed_body.dig("props", "game_options", "filters", "code")
  end

  test "picker sorting covers all matching pages and bulk matches are optional scoped summaries" do
    matches = 30.times.map do |index|
      @season.games.create!(external_id: "EXAMPLE-BULK-#{index}", code: "EXAMPLE-CODE", home_team: "Fictional Alpha", away_team: "Fictional Bravo", date: "2031-02-17", fees_cents: index * 100)
    end
    other = Season.create!(year: 2032, sheet_name: "Example", issuer: @season.issuer)
    other.games.create!(external_id: "EXAMPLE-OTHER-YEAR", code: "EXAMPLE-CODE", home_team: "Fictional Alpha", away_team: "Fictional Bravo", date: "2032-02-17")
    filters = { code: [ "EXAMPLE-CODE" ], home_team: [ "Fictional Alpha" ], away_team: [ "Fictional Bravo" ] }
    get new_invoice_path, params: { game_filters: filters, game_sort: "fees_cents", game_direction: "desc", game_page: 2, game_per_page: 10 }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "game_options")
    options = response.parsed_body.dig("props", "game_options")
    assert_equal({ "column" => "fees_cents", "direction" => "desc" }, options["sort"])
    assert_equal (11..20).to_a.reverse.map { |index| index * 100 }, options["games"].map { |game| game["fees_cents"] }
    assert_equal 31, options.dig("pagination", "total")
    assert_not response.parsed_body["props"].key?("matching_games")
    assert_no_difference [ "Invoice.count", "InvoiceDraft.count", "InvoiceGame.count" ] do
      get edit_invoice_draft_path(@draft), params: { game_filters: filters, game_page: 2, game_per_page: 10 }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "matching_games")
    end
    props = response.parsed_body.fetch("props")
    assert_equal [ @game.id, *matches.map(&:id) ].sort, props["matching_games"].map { |game| game["id"] }.sort
    assert_not props.key?("invoice")
    assert_not props.key?("game_options")
    refute_includes response.body, "Only on demand"
    refute_includes response.body, "Fictional Rowan"
    refute_includes response.body, "Private other title"
    get new_invoice_path, params: { game_filters: { date_from: "invalid" } }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "matching_games")
    assert_empty response.parsed_body.dig("props", "matching_games")
  end

  private
  def inertia_headers = { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
end
