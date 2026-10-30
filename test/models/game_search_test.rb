require "test_helper"

class GameSearchTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @alpha = make_game("EXAMPLE-A", home_team: "Example Alpha", away_team: "Example Bravo", code: "EXAMPLE-JUNIOR", date: "2031-02-17", location: "Fictional North Field", officials: [ { name: "Fictional Rowan", position: "Referee", fee_cents: 1337 } ])
    @bravo = make_game("EXAMPLE-B", home_team: "Example Bravo", away_team: "Example Alpha", code: "EXAMPLE-SENIOR", date: "2031-02-20", location: "Fictional South Field")
    @literal = make_game("EXAMPLE-C", home_team: "Example_% Club", away_team: "Example Delta", date: "2031-03-05")
    @unrelated = make_game("EXAMPLE-D", home_team: "ExampleZZ Club", away_team: "Example Delta", date: "2031-04-05")
    invoice = @season.invoices.create!(number: "EXAMPLE-LINKED", recipient: "Fictional Club", description: "Example fees", issued_on: "2031-02-17", line_items_attributes: [ { description: "Example", quantity: 1, rate_cents: 1337 } ], game_ids: [ @alpha.id ])
    @draft = InvoiceDraft.create!(user: users(:one), season: @season, client_key: "example-filter-workbench", data: { "recipient" => "Fictional workbench", "game_ids" => [ @bravo.id ] })
    InvoiceDraft.create!(user: users(:two), season: @season, client_key: "example-private-workbench", data: { "recipient" => "Other user's private title", "game_ids" => [ @literal.id ] })
    assert_equal [ @alpha.id ], invoice.game_ids
  end

  test "home away code venue official and inclusive dates combine" do
    assert_equal [ @alpha.id ], ids(home_team: "ALPHA", away_team: "bravo", code: "junior", location: "north", official: "rowan", date_from: "2031-02-17", date_to: "2031-02-17")
    assert_equal [ @bravo.id ], ids(home_team: "bravo", away_team: "alpha")
    assert_empty ids(home_team: "alpha", away_team: "alpha")
    assert_equal [ @alpha.id, @bravo.id ].sort, ids(date_from: "2031-02-17", date_to: "2031-02-20").sort
    assert_equal [ @alpha.id ], ids(q: "North Field")
  end

  test "search treats percent underscore and backslash literally" do
    assert_equal [ @literal.id ], ids(home_team: "_%")
    assert_equal [ @literal.id ], ids(q: "_%")
    @literal.update!(location: 'Example\Field')
    assert_equal [ @literal.id ], ids(location: 'Example\Field')
  end

  test "multi-select fields match any selected value exactly and combine across fields" do
    assert_equal [ @alpha.id, @bravo.id ].sort, ids(code: [ "EXAMPLE-JUNIOR", "EXAMPLE-SENIOR" ]).sort
    assert_equal [ @alpha.id ], ids(home_team: [ "Example Alpha", "Example_% Club" ], away_team: [ "Example Bravo" ], code: [ "EXAMPLE-JUNIOR", "EXAMPLE-SENIOR" ])
    assert_empty ids(code: [ "JUNIOR" ])
    assert_equal [ @literal.id ], ids(home_team: [ "Example_% Club" ])
    assert_equal @season.games.count, ids(code: [], home_team: [], away_team: []).size
  end

  test "choices include the full master schedule and exclude other years and blank values" do
    30.times { |index| make_game("EXAMPLE-OPTION-#{index}", code: "EXAMPLE-CODE-#{index}") }
    other = Season.create!(year: 2032, sheet_name: "Example", issuer: @season.issuer)
    other.games.create!(external_id: "EXAMPLE-OTHER-YEAR", date: "2032-01-01", code: "PRIVATE-OTHER-YEAR")
    choices = GameSearch.choices(@season.games)
    assert_equal 32, choices.fetch("code").size
    assert_includes choices.fetch("code"), "EXAMPLE-CODE-29"
    assert_not_includes choices.fetch("code"), "PRIVATE-OTHER-YEAR"
    assert_not_includes choices.fetch("code"), nil
    assert_equal [ "Example Alpha", "Example Bravo", "ExampleZZ Club", "Example_% Club" ].sort, choices.fetch("home_team").sort
  end

  test "invoice and workbench filters include only visible workbenches" do
    assert_equal [ @alpha.id ], ids(link_status: "invoiced")
    assert_equal [ @bravo.id ], ids(link_status: "workbench")
    assert_equal [ @alpha.id, @bravo.id ].sort, ids(link_status: "linked").sort
    assert_equal [ @literal.id, @unrelated.id ].sort, ids(link_status: "unlinked").sort
  end

  test "bad or reversed dates return an explanation and no unbounded results" do
    [ { date_from: "not-a-date" }, { date_to: "2031-02-30" }, { date_from: "2031-03-01", date_to: "2031-02-01" } ].each do |values|
      search = GameSearch.new(@season.games, values.stringify_keys, user: users(:one))
      assert_empty search.results
      assert search.errors.any?
    end
  end

  test "previewed workbenches use saved game links until raw selections explicitly replace them" do
    invoice = Invoice.find_by!(number: "EXAMPLE-LINKED")
    work = InvoiceDraft.create!(user: users(:one), season: @season, invoice: invoice, client_key: "example-previewed-workbench", data: {})
    assert_equal [ @alpha.id, @bravo.id ].sort, ids(link_status: "workbench").sort
    work.update!(data: { "game_ids" => [] })
    assert_equal [ @bravo.id ], ids(link_status: "workbench")
    assert_equal [ @alpha.id ], ids(link_status: "invoiced")
  end

  private
  def make_game(id, **attrs)
    @season.games.create!({ external_id: id, date: "2031-02-17", fees_cents: 1337 }.merge(attrs))
  end
  def ids(**filters)
    GameSearch.new(@season.games, filters.stringify_keys, user: users(:one)).results.pluck(:id)
  end
end
