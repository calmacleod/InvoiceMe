require "test_helper"

class OfficialEarningsSheetTest < ActiveSupport::TestCase
  class Google
    attr_reader :payload, :writes

    def request(method, url, json:, **)
      raise "Unexpected endpoint" unless method == :post && url == "https://sheets.googleapis.com/v4/spreadsheets?fields=spreadsheetId"

      @payload = json
      { "spreadsheetId" => "fictional-earnings-sheet" }
    end

    def batch_update(id, writes)
      raise "Unexpected spreadsheet" unless id == "fictional-earnings-sheet"

      @writes = writes
    end
  end

  test "exports reviewed earnings with typed currency, cheque values, and named adjustments" do
    season = seasons(:current)
    official = season.official_payments.create!(official_name: "Harper, Casey", game_fee_adjustment_cents: 13_573,
      registration_cents: 4_075, other_cents: 123, reviewed_at: Time.current, cheque_number: "0019",
      adjustments: [ { "label" => "=Training", "amount_cents" => 575 } ])
    google = Google.new
    assert_equal "fictional-earnings-sheet", OfficialEarningsSheet.new(season, api: google).export!
    register = google.payload.fetch(:sheets).first
    assert_equal "Officials Payment Amounts", register.dig(:properties, :title)
    register_data, details = google.writes.filter_map { |write| write[:updateCells] }
    register_row = register_data.dig(:rows, 1, :values)
    assert_equal 6.98, register_row.dig(7, :userEnteredValue, :numberValue)
    assert_equal official.net_cents.fdiv(100), register_row.dig(12, :userEnteredValue, :numberValue)
    assert_equal "0019", register_row.dig(13, :userEnteredValue, :stringValue)
    assert_equal 1, register_row.dig(16, :userEnteredValue, :numberValue)
    assert_equal 1, details.dig(:rows, 1, :values, 0, :userEnteredValue, :numberValue)
    assert_equal "=Training", details.dig(:rows, 1, :values, 2, :userEnteredValue, :stringValue)
    assert_equal "#{season.year} Final Officials Earnings", google.writes.last.dig(:updateSpreadsheetProperties, :properties, :title)
  end

  test "requires a full review before creating a final sheet" do
    season = seasons(:current)
    season.official_payments.create!(official_name: "Vale, Jordan")
    google = Google.new
    assert_raises(GoogleApi::Error) { OfficialEarningsSheet.new(season, api: google).export! }
    assert_nil google.payload
  end
end
