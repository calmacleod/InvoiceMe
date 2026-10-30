require "test_helper"
require_relative "../test_helpers/fake_google"

class GoogleLedgerTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @season.update!(spreadsheet_id: "example-sheet", drive_folder_id: "example-folder")
    @invoice = @season.invoices.create!(number: "2026_Example", recipient: "Example Club", description: "Fictional services", issued_on: Date.new(2031, 9, 15),
      line_items_attributes: [ { description: "Example service", quantity: 2, rate: "13.37" } ])
    @api = FakeGoogle.new
    @api.sheet["tables"] = [ {
      "tableId" => "example-table", "range" => { "sheetId" => 123, "startRowIndex" => 1, "endRowIndex" => 7, "startColumnIndex" => 0, "endColumnIndex" => 12 },
      "rowsProperties" => { "footerColorStyle" => { "rgbColor" => {} } },
      "columnProperties" => [ { "columnIndex" => 1, "columnType" => "DATE" }, { "columnIndex" => 8, "columnType" => "DATE" },
        { "columnIndex" => 7, "columnType" => "DROPDOWN", "dataValidationRule" => { "condition" => { "type" => "ONE_OF_LIST", "values" => [ { "userEnteredValue" => "Cheque" } ] } } } ]
    } ]
    @api.rows[3] = [ "2031_Other", "2031-09-10", "Other fictional invoice", "Example Coordinator", 10, 0, 10 ]
    (4..7).each do |row|
      @api.rows[row] = [ nil, nil, nil, nil, nil, 0, 0 ]
      @api.cells[row] = Array.new(9) { {} }
      @api.cells[row][6] = { "userEnteredValue" => { "formulaValue" => "=E#{row}-F#{row}" }, "userEnteredFormat" => { "numberFormat" => { "type" => "CURRENCY" } } }
    end
    @api.rows[8] = [ nil, nil, nil, nil, 10, 0, 10 ]
  end

  test "uses the first free table row despite template zeros formulas and a populated footer" do
    ledger.check_number_available!(@invoice)
    ledger.sync(@invoice)
    assert_equal 4, @invoice.reload.ledger_row
    assert_equal "2026_Example", @api.rows[4][0]
    assert_equal 26.74, @api.rows[4][6]
    assert_equal (Date.new(2031, 9, 15) - Date.new(1899, 12, 30)).to_i, @api.rows[4][1]
    assert_equal "=E4-F4", @api.cells[4][6].dig("userEnteredValue", "formulaValue")
    assert_equal "CURRENCY", @api.cells[4][6].dig("userEnteredFormat", "numberFormat", "type")
    assert_equal [ nil, nil, nil, nil, 10, 0, 10 ], @api.rows[8]
    assert_equal "userEnteredValue", @api.batches.first.first.dig(:updateCells, :fields)
  end

  test "the contact column receives only the first available email in invoice order" do
    @invoice.update!(contacts: [ { name: "Fictional Coordinator", email: "" }, { name: "Fictional Avery", email: " AVERY@EXAMPLE.TEST " }, { name: "Fictional Rowan", email: "rowan@example.test" } ])
    ledger.sync(@invoice)
    assert_equal "avery@example.test", @api.rows[4][3]
    assert_equal({ stringValue: "avery@example.test" }, @api.batches.last.first.dig(:updateCells, :rows, 0, :values, 3, :userEnteredValue))
    @invoice.update!(contacts: @invoice.contacts.reverse)
    ledger.sync(@invoice)
    assert_equal "rowan@example.test", @api.rows[4][3]
    @invoice.update!(contacts: [ { name: "Fictional Coordinator", email: "" } ])
    ledger.sync(@invoice)
    assert_nil @api.rows[4][3]
    assert_empty @api.batches.last.first.dig(:updateCells, :rows, 0, :values, 3)
  end

  test "legacy combined contacts export a bare email and legacy names leave the people column blank" do
    @invoice.update!(contact: "Fictional Avery <avery@example.test>")
    ledger.sync(@invoice)
    assert_equal "avery@example.test", @api.rows[4][3]
    @invoice.update!(contact: "Fictional Avery")
    ledger.sync(@invoice)
    assert_nil @api.rows[4][3]
  end

  test "partially entered rows and notes in extra table columns are retained" do
    @api.rows[4][2] = "Fictional draft in progress"
    @api.rows[5][11] = "Fictional reserved row"
    ledger.sync(@invoice)
    assert_equal 6, @invoice.reload.ledger_row
    assert_equal "Fictional draft in progress", @api.rows[4][2]
    assert_equal "Fictional reserved row", @api.rows[5][11]
  end

  test "a full table stops instead of using its footer or writing below it" do
    (4..6).each { |row| @api.rows[row][0] = "2031_Occupied_#{row}" }
    error = assert_raises(GoogleApi::Error) { ledger.check_number_available!(@invoice) }
    assert_includes error.message, "no available rows"
    assert_raises(GoogleApi::Error) { ledger.sync(@invoice) }
    assert_nil @invoice.reload.ledger_row
    assert_empty @api.batches
  end

  test "an existing invoice stays in its table row when an earlier row is empty" do
    @invoice.finalize!
    @invoice.update!(ledger_row: 5, published_at: Time.current)
    @api.rows[5] = [ @invoice.number, "2031-09-15", @invoice.description, "", 26.74, 0, 26.74 ]
    ledger.sync(@invoice)
    assert_equal 5, @invoice.reload.ledger_row
    assert_nil @api.rows[4][0]
  end

  test "a misplaced existing invoice is moved inside the table in one atomic batch" do
    misplaced_invoice!
    ledger.sync(@invoice)
    assert_equal 4, @invoice.reload.ledger_row
    assert_equal @invoice.number, @api.rows[4][0]
    assert @api.rows[9].first(9).all?(&:nil?)
    assert_equal 1, @api.batches.size
    assert_equal 2, @api.batches.first.size
    assert_equal 8, @api.batches.first.last.dig(:updateCells, :range, :startRowIndex)
    assert_equal 9, @api.batches.first.last.dig(:updateCells, :range, :endColumnIndex)
    assert_equal "=E4-F4", @api.cells[4][6].dig("userEnteredValue", "formulaValue")
    assert_equal [ nil, nil, nil, nil, 10, 0, 10 ], @api.rows[8]
  end

  test "a lost relocation acknowledgement retries the same row without duplicating or clearing unrelated data" do
    misplaced_invoice!
    @api.after_write_error = GoogleApi::TransientError.new("Fictional lost response")
    assert_raises(GoogleApi::TransientError) { ledger.sync(@invoice) }
    assert_equal 4, @invoice.reload.ledger_row
    @api.after_write_error = nil
    ledger.sync(@invoice)
    assert_equal 1, @api.rows.values.count { |row| row[0] == @invoice.number }
    assert_equal 1, @api.batches.last.size
    assert_equal 4, @invoice.reload.ledger_row
  end

  test "a misplaced row with additional notes is never silently cleared" do
    misplaced_invoice!
    @api.rows[9][11] = "Fictional handwritten note"
    error = assert_raises(GoogleApi::Error) { ledger.sync(@invoice) }
    assert_includes error.message, "notes outside columns"
    assert_equal 9, @invoice.reload.ledger_row
    assert_empty @api.batches
  end

  test "a pending row occupied by another invoice is never overwritten" do
    @invoice.finalize!
    @invoice.update!(ledger_row: 3)
    error = assert_raises(GoogleApi::Error) { ledger.sync(@invoice) }
    assert_includes error.message, "occupied"
    assert_equal "2031_Other", @api.rows[3][0]
    assert_empty @api.batches
  end

  test "row occupancy is rechecked immediately before writing" do
    @api.define_singleton_method(:ledger_cells) do |spreadsheet, range|
      rows[4][0] = "2031_Concurrent_Example"
      super(spreadsheet, range)
    end
    assert_raises(GoogleApi::Error) { ledger.sync(@invoice) }
    assert_empty @api.batches
  end

  test "formulas in input columns are protected and invalid payment dropdown choices stop" do
    @api.cells[4][4] = { "userEnteredValue" => { "formulaValue" => "=0" } }
    error = assert_raises(GoogleApi::Error) { ledger.sync(@invoice) }
    assert_includes error.message, "formulas in invoice input columns"
    @api.cells[4][4] = {}
    @invoice.finalize!
    @invoice.payments.create!(amount_cents: 100, received_on: Date.new(2031, 9, 16), method: "Other")
    error = assert_raises(GoogleApi::Error) { ledger.sync(@invoice) }
    assert_includes error.message, "Payment Method column does not allow Other"
    assert_empty @api.batches
  end

  test "duplicate numbers and a mismatched table configuration are rejected" do
    misplaced_invoice!
    @api.rows[4][0] = @invoice.number
    assert_raises(GoogleApi::Error) { ledger.sync(@invoice) }
    @api.sheet["tables"].first["range"]["startRowIndex"] = 20
    assert_raises(GoogleApi::Error) { ledger }
    assert_empty @api.batches
  end

  test "plain ledgers still fill the first available row" do
    @api.sheet.delete("tables")
    ledger.sync(@invoice)
    assert_equal 4, @invoice.reload.ledger_row
    assert_equal "2031-09-15", @api.rows[4][1]
  end

  test "an incorrect balance formula is preserved and reported instead of marking the export complete" do
    @api.cells[4][6]["userEnteredValue"]["formulaValue"] = "=0"
    error = assert_raises(GoogleApi::Error) { ledger.sync(@invoice) }
    assert_includes error.message, "balance formula"
    assert_equal "=0", @api.cells[4][6].dig("userEnteredValue", "formulaValue")
    assert_nil @invoice.reload.published_at
  end

  private

  def ledger = GoogleLedger.new(@api, @season.destination)

  def misplaced_invoice!
    @invoice.finalize!
    @invoice.update!(ledger_row: 9, published_at: Time.current, google_doc_id: "example-doc", google_pdf_id: "example-pdf")
    @api.rows[9] = [ @invoice.number, "2031-09-15", @invoice.description, "", 26.74, 0, 26.74 ]
  end
end
