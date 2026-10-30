require "test_helper"

class GameOrderTest < ActiveSupport::TestCase
  test "every supported column sorts both directions and keeps ties stable" do
    scope = seasons(:current).games
    first = scope.create!(external_id: "EXAMPLE-A", code: "example a", date: "2031-02-17", home_team: "Example Alpha", away_team: "Example Alpha", location: "Example Arena", fees_cents: 1337, officials: [ { name: "Example Avery" } ])
    last = scope.create!(external_id: "EXAMPLE-B", code: "EXAMPLE B", date: "2031-02-18", home_team: "Example Bravo", away_team: "Example Bravo", location: "Example Field", fees_cents: 2448, officials: [ { name: "Example Blair" }, { name: "Example Casey" } ])
    GameOrder::COLUMNS.each_key do |column|
      assert_equal [ first.id, last.id ], GameOrder.new(column, "asc").apply(scope).pluck(:id), column
      assert_equal [ last.id, first.id ], GameOrder.new(column, "desc").apply(scope).pluck(:id), column
    end
    last.update!(fees_cents: first.fees_cents)
    assert_equal [ first.id, last.id ], GameOrder.new("fees_cents", "desc").apply(scope).pluck(:id)
    invalid = GameOrder.new("date; DROP TABLE games", "asc; DROP TABLE games")
    assert_equal({ column: "date", direction: "desc" }, invalid.props)
    assert_equal [ last.id, first.id ], invalid.apply(scope).pluck(:id)
  end
end
