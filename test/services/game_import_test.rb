require "test_helper"
require "zip"
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

  test "XLSX imports retain text and normalize spreadsheet dates and numeric fees" do
    with_example_xlsx do |upload|
      headers, rows, info = GameImport.read(upload)
      assert_equal HEADERS, headers
      assert_empty info
      importer = GameImport.new(headers, rows, GameImport.guess(headers)).parse
      assert_empty importer.errors
      game = importer.games.fetch("910000001")
      assert_equal "EXAMPLE-LEAGUE", game[:code]
      assert_equal Date.new(2031, 9, 15), game[:date]
      assert_equal 2345, game[:fees_cents]
      assert_equal [ { "name" => "Example Official", "fee_cents" => 2345 } ], game[:officials]
    end
  end

  private

  def with_example_xlsx
    sheet_namespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    relationship_namespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    files = {
      "[Content_Types].xml" => <<~XML,
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
      XML
      "_rels/.rels" => %(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="#{relationship_namespace}/officeDocument" Target="xl/workbook.xml"/></Relationships>),
      "xl/workbook.xml" => %(<workbook xmlns="#{sheet_namespace}" xmlns:r="#{relationship_namespace}"><sheets><sheet name="Example games" sheetId="1" r:id="rId1"/></sheets></workbook>),
      "xl/_rels/workbook.xml.rels" => %(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="#{relationship_namespace}/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="#{relationship_namespace}/styles" Target="styles.xml"/></Relationships>),
      "xl/styles.xml" => %(<styleSheet xmlns="#{sheet_namespace}"><cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="14" applyNumberFormat="1"/></cellXfs></styleSheet>),
      "xl/worksheets/sheet1.xml" => <<~XML
        <worksheet xmlns="#{sheet_namespace}"><dimension ref="A1:E2"/><sheetData>
          <row r="1">#{HEADERS.each_with_index.map { |header, index| %(<c r="#{('A'.ord + index).chr}1" t="inlineStr"><is><t>#{header}</t></is></c>) }.join}</row>
          <row r="2">
            <c r="A2" t="inlineStr"><is><t>910000001</t></is></c>
            <c r="B2" t="inlineStr"><is><t>EXAMPLE-LEAGUE</t></is></c>
            <c r="C2" s="1"><v>#{(Date.new(2031, 9, 15) - Date.new(1899, 12, 30)).to_i}</v></c>
            <c r="D2" t="inlineStr"><is><t>Example Official</t></is></c>
            <c r="E2"><v>23.45</v></c>
          </row>
        </sheetData></worksheet>
      XML
    }
    Tempfile.create([ "example-games", ".xlsx" ]) do |file|
      Zip::OutputStream.open(file.path) do |zip|
        files.each do |name, xml|
          zip.put_next_entry(name)
          zip.write(xml)
        end
      end
      yield Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    end
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
