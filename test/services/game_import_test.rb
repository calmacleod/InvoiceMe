require "test_helper"
class GameImportTest < ActiveSupport::TestCase
  HEADERS = ["Game #", "Game Code", "Date", "Official", "Amount Paid"]
  test "groups officials by game and repeat import replaces rather than adds fees" do
    season = Season.create!(year: 2026, issuer: Season::DEFAULT_ISSUER)
    rows = [["10", "CJFL", "2026-10-25", "Ref A", "100.00"], ["10", "CJFL", "2026-10-25", "Ref B", "125.25"]]
    importer = GameImport.new(HEADERS, rows, GameImport.guess(HEADERS)).parse
    assert_empty importer.errors
    2.times { importer.commit!(season) }
    assert_equal 1, season.games.count
    assert_equal 22525, season.games.first.fees_cents
    assert_equal 2, season.games.first.officials.size
    assert_equal 2, season.games.first.source.size
  end
  test "bad rows prevent the entire import" do
    season = Season.create!(year: 2026, issuer: Season::DEFAULT_ISSUER)
    importer = GameImport.new(HEADERS, [["10", "CJFL", "not-date", "A", "10"]], GameImport.guess(HEADERS)).parse
    assert importer.errors.any?
    assert_raises(ArgumentError) { importer.commit!(season) }
    assert_equal 0, season.games.count
  end
  test "explicit date format resolves day month ambiguity" do
    importer = GameImport.new(HEADERS, [["10", "CJFL", "05/06/2026", "A", "10"]], GameImport.guess(HEADERS), date_format: "%d/%m/%Y").parse
    assert_equal Date.new(2026,6,5), importer.games["10"][:date]
  end
  test "separate position columns retain each official and fee" do
    headers = ["Game #", "Date", "Referee", "Referee Fee", "Umpire", "Umpire Fee"]
    mapping = GameImport.guess(headers).merge("official_columns" => {"0" => {"name" => "Referee", "amount" => "Referee Fee"}, "1" => {"name" => "Umpire", "amount" => "Umpire Fee"}})
    importer = GameImport.new(headers, [["10", "2026-10-25", "A", "100", "B", "90"]], mapping).parse
    assert_empty importer.errors
    assert_equal 19000, importer.games["10"][:fees_cents]
    assert_equal [10000,9000], importer.games["10"][:officials].map { |o| o["paid_cents"] }
  end
  test "duplicate rows are rejected" do
    row = ["10", "CJFL", "2026-10-25", "A", "100"]
    importer = GameImport.new(HEADERS, [row,row], GameImport.guess(HEADERS)).parse
    assert importer.errors.any? { |e| e.include?("Duplicate row") }
  end
end
