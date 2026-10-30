class GoogleLedger
  def initialize(api, destination)
    @api, @destination = api, destination
    @spreadsheet = destination.fetch("spreadsheet_id")
    @tab = "'#{destination.fetch('sheet_name').gsub("'", "''")}'"
    @start = destination.fetch("ledger_start_row").to_i
    sheet = @api.sheet_metadata(@spreadsheet, destination.fetch("sheet_name"))
    @sheet_id = sheet.fetch("properties").fetch("sheetId")
    @scan_end = [ sheet.dig("properties", "gridProperties", "rowCount"), 100_000 ].min
    tables = sheet.fetch("tables", [])
    candidates = tables.select do |table|
      range = table.fetch("range")
      range.fetch("startRowIndex", 0) == @start - 2 && range.fetch("startColumnIndex", 0) == 0 && range.fetch("endColumnIndex") >= 9
    end
    if candidates.size > 1 || (tables.any? && candidates.empty?)
      raise GoogleApi::Error, "The configured ledger header does not identify one invoice table. Check Settings."
    end
    @table = candidates.first
    @end = @table ? @table.fetch("range").fetch("endRowIndex") : @scan_end
    @end -= 1 if @table&.dig("rowsProperties", "footerColorStyle")
    @width = @table ? @table.fetch("range").fetch("endColumnIndex") : 9
    @last_column = column_name(@width)
  end

  def check_number_available!(invoice)
    rows = read_rows
    if rows.any? { |row| row[0].to_s == invoice.number }
      raise GoogleApi::Error, "Invoice number already exists in the master sheet. Choose a different invoice number before publishing."
    end
    available_row(rows) || raise(GoogleApi::Error, "The invoice table has no available rows. Add a row inside the table and retry.")
  end

  def sync(invoice)
    rows = read_rows
    matches = rows.each_index.select { |index| rows[index][0].to_s == invoice.number }
    raise GoogleApi::Error, "Invoice number appears more than once in the master sheet" if matches.size > 1
    source = matches.first && matches.first + @start
    if source && @table && source > @end && source <= @table.fetch("range").fetch("endRowIndex")
      raise GoogleApi::Error, "The invoice number is in the table footer. Check the master sheet before syncing."
    end
    if source && !invoice.ledger_row
      raise GoogleApi::Error, "Invoice number already exists in the master sheet. Resolve it before publishing."
    end
    if invoice.ledger_row && !source && invoice.published_at
      raise GoogleApi::Error, "The invoice's ledger row was removed or renamed. Check the master sheet."
    end
    row = source || invoice.ledger_row
    row = available_row(rows) unless row && inside?(row)
    raise GoogleApi::Error, "The invoice table has no available rows. Add a row inside the table and retry." unless row
    current = @api.ledger_cells(@spreadsheet, "#{@tab}!A#{row}:#{@last_column}#{row}")
    unless source == row || empty_row?(current.map { |cell| cell.fetch("effectiveValue", {}).values.first })
      raise GoogleApi::Error, "The target ledger row is occupied"
    end
    if source && source != row && rows.fetch(source - @start).drop(9).any?(&:present?)
      raise GoogleApi::Error, "The misplaced ledger row has notes outside columns A–I. Move those notes with the invoice before syncing."
    end
    values = invoice_values(invoice, current)
    requests = [ { updateCells: { range: grid_range(row), rows: [ { values: values } ], fields: "userEnteredValue" } } ]
    if source && source != row
      # One atomic batch moves only the invoice inputs. The table's formulas,
      # formatting, validation, footer, and unrelated columns remain in place.
      requests << { updateCells: { range: grid_range(source), rows: [ { values: Array.new(9) { {} } } ], fields: "userEnteredValue" } }
    end
    # Persist intent before the remote write. A lost response is recovered by
    # locating the invoice number again, including after an atomic relocation.
    invoice.update!(ledger_row: row)
    @api.batch_update(@spreadsheet, requests)
    written = @api.values(@spreadsheet, "#{@tab}!A#{row}:I#{row}").first || []
    amounts = written[4, 3].to_a.map { |value| BigDecimal(value.to_s, exception: false)&.*(100)&.round&.to_i }
    unless written[0].to_s == invoice.number && amounts == [ invoice.total_cents, invoice.received_cents, invoice.owed_cents ]
      raise GoogleApi::Error, "The ledger amounts did not match after writing. Check the balance formula and retry."
    end
  end

  private

  def read_rows = @api.values(@spreadsheet, "#{@tab}!A#{@start}:#{@last_column}#{@scan_end}")
  def inside?(row) = row.between?(@start, @end)
  def available_row(rows) = (@start..@end).find { |row| empty_row?(rows[row - @start] || []) }
  def empty_row?(values)
    values.each_with_index.all? { |value, index| value.blank? || ([ 4, 5, 6 ].include?(index) && value.is_a?(Numeric) && value.zero?) }
  end
  def grid_range(row)
    { sheetId: @sheet_id, startRowIndex: row - 1, endRowIndex: row, startColumnIndex: 0, endColumnIndex: 9 }
  end
  def column_name(number)
    name = +""
    while number > 0
      number, digit = (number - 1).divmod(26)
      name.prepend((65 + digit).chr)
    end
    name
  end
  def invoice_values(invoice, cells)
    if cells.each_with_index.any? { |cell, index| index < 9 && index != 6 && cell.dig("userEnteredValue", "formulaValue").present? }
      raise GoogleApi::Error, "The target ledger row has formulas in invoice input columns. Check the template before syncing."
    end
    payment = invoice.payments.order(:received_on, :id).last
    method = payment&.method.to_s
    condition = cells.dig(7, "dataValidation", "condition") || @table&.fetch("columnProperties", [])&.find { |column| column["columnIndex"] == 7 }&.dig("dataValidationRule", "condition")
    if method.present? && condition&.fetch("type") == "ONE_OF_LIST" && !condition.fetch("values").any? { |option| option["userEnteredValue"] == method }
      raise GoogleApi::Error, "The ledger's Payment Method column does not allow #{method}. Check its dropdown options before syncing."
    end
    values = [ invoice.number, date_value(invoice.issued_on, 1, cells), invoice.description, invoice.contact_email, invoice.total_cents / 100.0, invoice.received_cents / 100.0, invoice.owed_cents / 100.0, method, date_value(payment&.received_on, 8, cells) ]
    values.each_with_index.map do |value, index|
      formula = cells.dig(index, "userEnteredValue", "formulaValue") if index == 6
      entered = formula ? { formulaValue: formula } : value.is_a?(Numeric) ? { numberValue: value } : value.present? ? { stringValue: value } : nil
      entered ? { userEnteredValue: entered } : {}
    end
  end
  def date_value(date, index, cells)
    return "" unless date
    column_type = @table&.fetch("columnProperties", [])&.find { |column| column["columnIndex"] == index }&.fetch("columnType", nil)
    formatted_date = cells.dig(index, "userEnteredFormat", "numberFormat", "type") == "DATE"
    column_type == "DATE" || formatted_date ? (date - Date.new(1899, 12, 30)).to_i : date.iso8601
  end
end
