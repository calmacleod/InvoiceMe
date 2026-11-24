require "test_helper"

class ExpenseSpreadsheetTest < ActiveSupport::TestCase
  class FakeGoogle
    attr_reader :creates, :batches, :finds
    attr_accessor :duplicate, :folder_writable

    def initialize
      @creates = []
      @batches = []
      @finds = []
      @sheets = [ { "sheetId" => 0, "title" => "Sheet1", "gridProperties" => { "rowCount" => 1000, "columnCount" => 26 } } ]
      @folder_writable = true
    end

    def request(method, url, json: nil, operation:)
      case operation
      when "checking the Financials folder"
        { "mimeType" => "application/vnd.google-apps.folder", "capabilities" => { "canAddChildren" => folder_writable } }
      when "finding the yearly expense spreadsheet"
        @finds << URI.decode_www_form(URI(url).query).to_h.fetch("q")
        { "files" => duplicate ? [ { "id" => "other" }, { "id" => "duplicate" } ] : @creates.any? ? [ { "id" => "test-expenses" } ] : [] }
      when "creating the yearly expense spreadsheet"
        @creates << [ method, json ]
        { "id" => "test-expenses" }
      when "checking the expense spreadsheet tabs"
        { "sheets" => @sheets.map { |properties| { "properties" => properties } } }
      else
        raise "Unexpected Google operation: #{operation}"
      end
    end

    def batch_update(id, requests)
      @batches << [ id, requests ]
      requests.each do |request|
        if (sheet = (request[:addSheet] || request[:updateSheetProperties]))
          properties = sheet.fetch(:properties).deep_stringify_keys
          @sheets.reject! { |existing| existing["sheetId"] == properties["sheetId"] }
          @sheets << properties
        end
      end
    end
  end

  test "creates a tagged native spreadsheet in the selected folder and rewrites only the managed tabs" do
    season = seasons(:current)
    expense = season.expenses.new
    expense.save_details!(payee: "=Example Club", description: "Training dinner", incurred_on: "2026-10-12", category: "Training",
      total_cents: 4081, paid: true, paid_on: "2026-10-15", cheque_number: "0015", line_items: [ { description: "Snacks", category: "Meals", amount_cents: 1995 } ])
    api = FakeGoogle.new

    spreadsheet = -> { ExpenseSpreadsheet.new(year: season.year, folder_id: "financials-test", register: ExpenseRegister.new(season), api: api) }
    assert_equal "test-expenses", spreadsheet.call.sync!
    method, file = api.creates.sole
    assert_equal :post, method
    assert_equal [ [ "financials-test" ], "2026 Association Expenses", ExpenseSpreadsheet::MIME, { invoice_me: "expenses-2026" } ],
      file.values_at(:parents, :name, :mimeType, :appProperties)
    requests = api.batches.sole.last
    tabs = requests.filter_map { |req| (req[:addSheet] || req[:updateSheetProperties])&.dig(:properties, :title) }
    assert_equal [ "Expenses", "Line items", "By category" ], tabs

    expense_rows, items, categories = requests.filter_map { |req| req[:updateCells] }
    record = expense_rows.fetch(:rows).last.fetch(:values)
    assert_equal({ stringValue: "=Example Club" }, record[2].fetch(:userEnteredValue))
    assert_equal({ stringValue: "0015" }, record[11].fetch(:userEnteredValue))
    assert_equal 40.81, record[5].dig(:userEnteredValue, :numberValue)
    assert_equal 20.86, items.dig(:rows, 2, :values, 6, :userEnteredValue, :numberValue)
    assert_equal 40.81, categories.fetch(:rows).last.dig(:values, 1, :userEnteredValue, :numberValue)

    expense.destroy!
    assert_equal "test-expenses", spreadsheet.call.sync!
    assert_equal 1, api.creates.size
    assert_equal 2, api.finds.size
    last_ranges = api.batches.last.last.filter_map { |req| req[:updateCells] }
    assert_equal 1, last_ranges.first.fetch(:rows).size
    assert_equal 1000, last_ranges.first.dig(:range, :endRowIndex)
    assert_equal 14, last_ranges.first.dig(:range, :endColumnIndex)
  end

  test "a job marks the exact snapshot revision as synced and both edits and folder changes mark it stale" do
    season = seasons(:current)
    season.update!(financials_folder_id: "financials-test")
    sync = season.create_expense_sheet_sync!(status: "queued", run_token: "test-run")
    api = FakeGoogle.new
    original = GoogleApi.method(:new)
    GoogleApi.define_singleton_method(:new) { api }
    SyncExpenseSheetJob.perform_now(sync.id, "test-run")
    progress = sync.reload.progress
    assert_equal [ "succeeded", false, "https://docs.google.com/spreadsheets/d/test-expenses/edit" ], progress.values_at(:status, :stale, :url)

    season.expenses.create!(payee: "Example caterer", description: "Meeting snacks", incurred_on: "2026-11-04", category: "Meals", total_cents: 3310)
    assert ExpenseSheetSync.for_season(season.reload).fetch(:stale)
    season.update!(financials_folder_id: "other-year-folder")
    assert_nil ExpenseSheetSync.for_season(season.reload).fetch(:url)
  ensure
    GoogleApi.define_singleton_method(:new, original) if original
  end

  test "fails without writing when the folder is not writable or there are duplicate files" do
    season = seasons(:current)
    api = FakeGoogle.new
    sheet = ExpenseSpreadsheet.new(year: season.year, folder_id: "financials-test", register: ExpenseRegister.new(season), api: api)
    api.folder_writable = false
    assert_raises(GoogleApi::Error) { sheet.sync! }
    api.folder_writable = true
    api.duplicate = true
    assert_raises(GoogleApi::Error) { sheet.sync! }
    assert_empty api.creates
    assert_empty api.batches
  end
end
