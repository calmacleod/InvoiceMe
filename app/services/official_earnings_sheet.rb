class OfficialEarningsSheet
  DATE_EPOCH = Date.new(1899, 12, 30)
  CURRENCY = { type: "CURRENCY", pattern: "$#,##0.00;($#,##0.00)" }.freeze
  DATE = { type: "DATE", pattern: "yyyy-mm-dd" }.freeze
  HEADER = { backgroundColor: { red: 0.87, green: 0.92, blue: 0.88 }, textFormat: { bold: true }, wrapStrategy: "WRAP" }.freeze

  def initialize(season, api: nil)
    @season, @api = season, api
  end

  def export!
    payments = @season.official_payments.in_payment_order.to_a
    raise GoogleApi::Error, "Add officials before exporting earnings." if payments.empty?
    raise GoogleApi::Error, "Review every official before exporting the final earnings sheet." if payments.any? { |payment| !payment.reviewed_at }

    tabs = [ register(payments), adjustments(payments) ]
    title = "#{@season.year} Final Officials Earnings"
    draft = {
      properties: { title: "#{@season.year} Officials Earnings - export in progress", locale: "en_CA" },
      sheets: tabs.map { |tab, _requests| tab }
    }
    api = @api || GoogleApi.new
    id = api.request(:post, "https://sheets.googleapis.com/v4/spreadsheets?fields=spreadsheetId", json: draft, operation: "creating the earnings sheet").fetch("spreadsheetId")
    requests = tabs.flat_map { |_tab, writes| writes }
    requests << { updateSpreadsheetProperties: { properties: { title: title }, fields: "title" } }
    api.batch_update(id, requests)
    id
  end

  private

  def register(payments)
    headers = [ "Official", "Game Fees", "Association Fee", "Net Game Fees", "Travel/OT", "Evaluations", "Prepayment Refund", "Other",
      "Earnings prior to Deductions", "OFOA Registration", "Banquet", "#{@season.year + 1} Prepayment", "Net Amount", "Cheque Number", "Date Deposited", "Cheque Delivery", "Payment Number" ]
    rows = payments.map do |payment|
      cents = [
        payment.game_fees_cents, payment.association_fee_cents, payment.net_game_fees_cents, payment.travel_ot_cents,
        payment.evaluations_cents, payment.prepayment_refund_cents, payment.miscellaneous_cents, payment.earnings_before_deductions_cents,
        payment.registration_cents, payment.banquet_cents, payment.next_year_prepayment_cents, payment.net_cents
      ]
      deposit = payment.deposited_on ? number((payment.deposited_on - DATE_EPOCH).to_i, DATE) : {}
      [ string(payment.official_name), *cents.map { |value| currency(value) }, string(payment.cheque_number), deposit, string(payment.cheque_delivery), number(payment.payment_number) ]
    end
    tab(0, "Officials Payment Amounts", headers, rows, [ 200, *Array.new(12, 125), 120, 130, 180, 130 ])
  end

  def adjustments(payments)
    rows = payments.flat_map do |payment|
      payment.adjustments.map do |item|
        [ number(payment.payment_number), string(payment.official_name), string(item.fetch("label")), currency(item.fetch("amount_cents")) ]
      end
    end
    tab(1, "Adjustments", [ "Payment Number", "Official", "Adjustment", "Amount" ], rows, [ 130, 200, 320, 125 ])
  end

  def tab(sheet_id, title, headers, rows, widths)
    header = headers.map { |value| string(value).merge(userEnteredFormat: HEADER) }
    sheet = {
      properties: { sheetId: sheet_id, title: title, gridProperties: { rowCount: [ rows.size + 1, 2 ].max, columnCount: headers.size, frozenRowCount: 1, frozenColumnCount: 1 } }
    }
    write = { updateCells: { start: { sheetId: sheet_id, rowIndex: 0, columnIndex: 0 }, rows: [ header, *rows ].map { |values| { values: values } }, fields: "userEnteredValue,userEnteredFormat" } }
    resize = widths.each_with_index.map do |width, index|
      { updateDimensionProperties: { range: { sheetId: sheet_id, dimension: "COLUMNS", startIndex: index, endIndex: index + 1 }, properties: { pixelSize: width }, fields: "pixelSize" } }
    end
    [ sheet, [ write, *resize ] ]
  end

  def string(value)
    value.nil? ? {} : { userEnteredValue: { stringValue: value }, userEnteredFormat: { wrapStrategy: "WRAP" } }
  end

  def currency(cents) = number(cents.fdiv(100), CURRENCY)

  def number(value, format = nil)
    return {} if value.nil?

    cell = { userEnteredValue: { numberValue: value } }
    cell[:userEnteredFormat] = { numberFormat: format } if format
    cell
  end
end
