require "test_helper"

class WorkspacePerformanceTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    post select_year_path, params: { id: @season.id }
    60.times do |i|
      @season.games.create!(external_id: "EXAMPLE-#{i.to_s.rjust(3, '0')}", code: i.zero? ? "UNIQUE-CODE" : "EXAMPLE", date: Date.new(2031, 2, 17),
        officials: [ { name: "Private fictional official", fee_cents: 1337 } ], source: [ { "Paid By Team" => "No", "Private field" => "Fictional source value" } ])
    end
  end

  test "games are bounded summaries with stable pagination and details requested only on demand" do
    get games_path, headers: inertia_headers
    props = response.parsed_body.fetch("props")
    assert_equal 25, props["games"].size
    assert_equal 60, props.dig("pagination", "total")
    refute props.key?("game_detail")
    refute_includes response.body, "Private fictional official"
    refute_includes response.body, "Fictional source value"
    assert_equal 1, props["games"].first["official_count"]
    assert_equal "No", props["games"].first["paid_by_team"]
    first_ids = props["games"].map { |game| game["id"] }
    get games_path(page: 2), headers: inertia_headers
    assert_empty first_ids & response.parsed_body.dig("props", "games").map { |game| game["id"] }
    get games_path(q: "UNIQUE-CODE", page: 999), headers: inertia_headers
    assert_equal 1, response.parsed_body.dig("props", "pagination", "page")
    assert_equal 1, response.parsed_body.dig("props", "games").size
    get games_path(detail_id: first_ids.first), headers: inertia_headers.merge("X-Inertia-Partial-Component" => "games/Index", "X-Inertia-Partial-Data" => "game_detail")
    assert_equal "Private fictional official", response.parsed_body.dig("props", "game_detail", "officials", 0, "name")
    refute response.parsed_body["props"].key?("games")
    other = Season.create!(year: 2035, sheet_name: "Example", issuer: @season.issuer)
    game = other.games.create!(external_id: "OTHER", date: Date.current)
    get games_path(detail_id: game.id), headers: inertia_headers.merge("X-Inertia-Partial-Component" => "games/Index", "X-Inertia-Partial-Data" => "game_detail")
    assert_response :not_found
  end

  test "editor searches and pages just game options without serializing invoice or raw game data" do
    get new_invoice_path, headers: inertia_headers
    assert_equal 25, response.parsed_body.dig("props", "game_options", "games").size
    get new_invoice_path(game_q: "UNIQUE-CODE"), headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "game_options")
    assert_equal 1, response.parsed_body.dig("props", "game_options", "games").size
    refute response.parsed_body["props"].key?("invoice")
    refute_includes response.body, "Private fictional official"
  end

  test "invoice details preload linked invoice references instead of querying once per game" do
    invoice = @season.invoices.create!(number: "EXAMPLE-LINKS", recipient: "Example", description: "Fictional", issued_on: Date.current,
      line_items_attributes: [ { description: "Example", quantity: 1, rate_cents: 1337 } ], game_ids: @season.games.limit(20).pluck(:id))
    get invoice_path(invoice), headers: inertia_headers
    queries = []
    ActiveSupport::Notifications.subscribed(->(*args) { event = args.last; queries << event[:sql] if !event[:cached] && event[:name] != "SCHEMA" && event[:sql].start_with?("SELECT") }, "sql.active_record") do
      get invoice_path(invoice), headers: inertia_headers
    end
    assert_equal 20, response.parsed_body.dig("props", "invoice", "games").size
    assert_operator queries.size, :<=, 10, "Linked games must not add a query per game"
  end

  test "invoice register pages records while totals cover the whole season and search skips totals" do
    30.times do |i|
      @season.invoices.create!(number: "EXAMPLE-#{i}", recipient: "Example Club", description: "Fictional", issued_on: Date.current,
        line_items_attributes: [ { description: "Example", quantity: "0.005", rate_cents: 100 } ]).finalize!
    end
    get root_path, headers: inertia_headers
    assert_equal 25, response.parsed_body.dig("props", "invoices").size
    assert_equal 30, response.parsed_body.dig("props", "totals", "invoiced")
    queries = []
    ActiveSupport::Notifications.subscribed(->(*args) { queries << args.last[:sql] }, "sql.active_record") do
      get root_path(q: "EXAMPLE-29"), headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Index", "X-Inertia-Partial-Data" => "invoices,pagination,query")
    end
    assert_equal 1, response.parsed_body.dig("props", "invoices").size
    refute response.parsed_body["props"].key?("totals")
    refute queries.any? { |sql| sql.include?("SUM(") }, "Search should not recalculate season totals"
  end

  private
  def inertia_headers
    { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
  end
end
