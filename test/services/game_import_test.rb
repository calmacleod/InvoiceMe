require "test_helper"
class GameImportTest < ActiveSupport::TestCase
  HEADERS = [ "Game #", "Game Code", "Date", "Official", "Amount Paid" ]
  test "groups officials by game and repeat import replaces rather than adds fees" do
    season = seasons(:current)
    rows = [ [ "10", "CJFL", "2026-10-25", "Ref A", "100.00" ], [ "10", "CJFL", "2026-10-25", "Ref B", "125.25" ] ]
    importer = GameImport.new(HEADERS, rows, GameImport.guess(HEADERS)).parse
    assert_empty importer.errors
    2.times { importer.commit!(season) }
    assert_equal 1, season.games.count
    assert_equal 22525, season.games.first.fees_cents
    assert_equal 2, season.games.first.officials.size
    assert_equal 2, season.games.first.source.size
  end
  test "bad rows prevent the entire import" do
    season = seasons(:current)
    importer = GameImport.new(HEADERS, [ [ "10", "CJFL", "not-date", "A", "10" ] ], GameImport.guess(HEADERS)).parse
    assert importer.errors.any?
    assert_raises(ArgumentError) { importer.commit!(season) }
    assert_equal 0, season.games.count
  end
  test "explicit date format resolves day month ambiguity" do
    importer = GameImport.new(HEADERS, [ [ "10", "CJFL", "05/06/2026", "A", "10" ] ], GameImport.guess(HEADERS), date_format: "%d/%m/%Y").parse
    assert_equal Date.new(2026, 6, 5), importer.games["10"][:date]
  end
  test "separate position columns retain each official and fee" do
    headers = [ "Game #", "Date", "Referee", "Referee Fee", "Umpire", "Umpire Fee" ]
    mapping = GameImport.guess(headers).merge("official_columns" => { "0" => { "name" => "Referee", "amount" => "Referee Fee" }, "1" => { "name" => "Umpire", "amount" => "Umpire Fee" } })
    importer = GameImport.new(headers, [ [ "10", "2026-10-25", "A", "100", "B", "90" ] ], mapping).parse
    assert_empty importer.errors
    assert_equal 19000, importer.games["10"][:fees_cents]
    assert_equal [ 10000, 9000 ], importer.games["10"][:officials].map { |o| o["fee_cents"] }
  end
  test "duplicate rows are rejected" do
    row = [ "10", "CJFL", "2026-10-25", "A", "100" ]
    importer = GameImport.new(HEADERS, [ row, row ], GameImport.guess(HEADERS)).parse
    assert importer.errors.any? { |e| e.include?("Duplicate row") }
  end
end

class HorizonMasterFeesTest < ActiveSupport::TestCase
  test "native Horizon export expands repeated official tuples and excludes meetings" do
    upload = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/horizon_master_fees.csv"), "text/csv")
    headers, rows, info = GameImport.read(upload)
    importer = GameImport.new(headers, rows, GameImport.guess(headers)).parse
    assert_empty importer.errors
    assert_equal 1, info.fetch("skipped_meetings")
    assert_equal 2, importer.games.size
    game = importer.games.fetch("900000001")
    assert_equal "Fictional Field A", game[:location]
    assert_equal "TEST-LEAGUE", game[:code]
    assert_equal 3559, game[:fees_cents]
    assert_equal [ "Example, Alex", "Sample, Pat" ], game[:officials].map { |official| official["name"] }
    assert_equal [ "Referee", "Umpire" ], game[:officials].map { |official| official["position"] }
    assert_equal [ 1337, 2222 ], game[:officials].map { |official| official["fee_cents"] }
    assert_equal "No", game[:source].first["Paid By Team"]
    assert_empty importer.games.fetch("900000002")[:officials]
  end

  test "all twenty officials are retained in a wide Horizon game row" do
    raw = CSV.generate do |csv|
      csv << [ "Game ID#", "Game Date", "Game Time", "Home", "Away", "Field", "Game Code", "Paid By Team", "# of Officials", "Game Length (min)", "Officials/Positions" ]
      csv << [ "999", "02/17/2031", "1:00pm", "Example Alpha", "Example Bravo", "Fictional Field", "TEST-LEAGUE", "No", "20", "120" ] + 20.times.flat_map { |i| [ "Official #{i+1}", "Referee", "$1.23" ] }
    end
    upload = Struct.new(:original_filename, :size, :body) { def read = body }.new("horizon.csv", raw.bytesize, raw)
    headers, rows, = GameImport.read(upload)
    importer = GameImport.new(headers, rows, GameImport.guess(headers)).parse
    assert_empty importer.errors
    assert_equal 20, importer.games.fetch("999")[:officials].size
    assert_equal 2460, importer.games.fetch("999")[:fees_cents]
  end
end
