class ExpenseSpreadsheet
  DRIVE = "https://www.googleapis.com/drive/v3/files"
  SHEETS = "https://sheets.googleapis.com/v4/spreadsheets"
  MIME = "application/vnd.google-apps.spreadsheet"
  DATE_EPOCH = Date.new(1899, 12, 30)
  CURRENCY = { type: "CURRENCY", pattern: "$#,##0.00;($#,##0.00)" }.freeze
  DATE = { type: "DATE", pattern: "yyyy-mm-dd" }.freeze
  HEADER = { backgroundColor: { red: 0.87, green: 0.92, blue: 0.88 }, textFormat: { bold: true }, wrapStrategy: "WRAP" }.freeze

  def initialize(year:, folder_id:, register:, api: GoogleApi.new)
    @year, @folder_id, @register, @api = year, folder_id, register, api
  end

  def sync!
    raise GoogleApi::Error, "Set the Financials folder for this year in Settings first." if @folder_id.blank?
    folder = @api.request(:get, "#{DRIVE}/#{@folder_id}?#{URI.encode_www_form(supportsAllDrives: true, fields: 'mimeType,trashed,capabilities(canAddChildren)')}",
      operation: "checking the Financials folder")
    unless folder["mimeType"] == "application/vnd.google-apps.folder" && !folder["trashed"] && folder.dig("capabilities", "canAddChildren")
      raise GoogleApi::Error, "The configured Financials folder is not a writable Google Drive folder."
    end

    spreadsheet_id = find_or_create_spreadsheet
    metadata = @api.request(:get, "#{SHEETS}/#{spreadsheet_id}?#{URI.encode_www_form(fields: 'sheets(properties(sheetId,title,gridProperties))')}",
      operation: "checking the expense spreadsheet tabs").fetch("sheets").map { |sheet| sheet.fetch("properties") }
    @api.batch_update(spreadsheet_id, write_requests(metadata))
    spreadsheet_id
  end

  private

  def find_or_create_spreadsheet
    key = "expenses-#{@year}"
    query = "trashed = false and '#{@folder_id}' in parents and mimeType = '#{MIME}' and appProperties has { key='invoice_me' and value='#{key}' }"
    lookup = URI.encode_www_form(q: query, fields: "files(id),nextPageToken", pageSize: 2, supportsAllDrives: true, includeItemsFromAllDrives: true)
    result = @api.request(:get, "#{DRIVE}?#{lookup}", operation: "finding the yearly expense spreadsheet")
    found = result.fetch("files")
    if found.size > 1 || result["nextPageToken"].present?
      raise GoogleApi::Error, "More than one expense spreadsheet was found in this Financials folder. Check Drive before syncing."
    end
    return found.first.fetch("id") if found.any?

    # The tag is written with the file so retries can recover a successful creation.
    @api.request(:post, "#{DRIVE}?supportsAllDrives=true&fields=id", operation: "creating the yearly expense spreadsheet",
      json: { name: "#{@year} Association Expenses", mimeType: MIME, parents: [ @folder_id ], appProperties: { invoice_me: key } }).fetch("id")
  end

  def write_requests(metadata)
    named = metadata.index_by { |properties| properties.fetch("title") }
    used_ids = metadata.map { |properties| properties.fetch("sheetId") }
    requests = [ { updateSpreadsheetProperties: { properties: { locale: "en_CA" }, fields: "locale" } } ]
    tabs.each do |title, labels, rows, widths|
      size = { rowCount: [ rows.size + 1, 2 ].max, columnCount: labels.size, frozenRowCount: 1 }
      sheet = named[title]
      if title == "Expenses" && !sheet && metadata.one? && metadata.first["title"] == "Sheet1"
        # Only rename Google's default tab when setting up the managed workbook.
        sheet = metadata.first
      end
      if sheet
        sheet_id = sheet.fetch("sheetId")
        grid = sheet.fetch("gridProperties")
        size[:rowCount] = [ size[:rowCount], grid.fetch("rowCount") ].max
        size[:columnCount] = [ size[:columnCount], grid.fetch("columnCount") ].max
        requests << { updateSheetProperties: { properties: { sheetId: sheet_id, title: title, gridProperties: size },
          fields: "title,gridProperties(rowCount,columnCount,frozenRowCount)" } }
      else
        sheet_id = used_ids.max.to_i + 1
        used_ids << sheet_id
        requests << { addSheet: { properties: { sheetId: sheet_id, title: title, gridProperties: size } } }
      end
      header = labels.map { |label| cell(label).merge(userEnteredFormat: HEADER) }
      # With range and a field mask, the unwritten tail is cleared in the same
      # atomic batch. Edits and deletions cannot leave duplicate or stale rows.
      requests << { updateCells: { range: { sheetId: sheet_id, startRowIndex: 0, endRowIndex: size[:rowCount], startColumnIndex: 0,
        endColumnIndex: labels.size }, rows: [ header, *rows ].map { |row| { values: row } }, fields: "userEnteredValue,userEnteredFormat" } }
      if !sheet || sheet["title"] != title
        widths.each_with_index do |width, index|
          requests << { updateDimensionProperties: { range: { sheetId: sheet_id, dimension: "COLUMNS", startIndex: index, endIndex: index + 1 },
            properties: { pixelSize: width }, fields: "pixelSize" } }
        end
      end
    end
    requests
  end

  def tabs
    [
      [ "Expenses", [ "Expense ID", "Date", "Payee", "Description", "Category", "Total (CAD)", "Itemized (CAD)", "Remainder (CAD)",
        "Paid", "Paid on", "Payment method", "Cheque number", "Reference", "Notes" ], expense_rows,
        [ 105, 115, 180, 260, 170, 120, 125, 130, 75, 115, 140, 135, 145, 280 ] ],
      [ "Line items", [ "Expense ID", "Date", "Payee", "Line", "Description", "Category", "Amount (CAD)" ], item_rows, [ 105, 115, 180, 75, 270, 170, 125 ] ],
      [ "By category", [ "Category", "Total (CAD)", "Paid (CAD)", "Unpaid (CAD)" ], category_rows, [ 230, 130, 130, 130 ] ]
    ]
  end

  def expense_rows
    @register.expenses.map do |expense|
      [ cell(expense.id), date(expense.incurred_on), cell(expense.payee), cell(expense.description), cell(expense.category), money(expense.total_cents),
        money(expense.itemized_cents), money(expense.remainder_cents), cell(expense.paid? ? "Paid" : "Unpaid"), date(expense.paid_on),
        cell(expense.payment_method), cell(expense.cheque_number), cell(expense.reference), cell(expense.notes) ]
    end
  end

  def item_rows
    @register.expenses.flat_map do |expense|
      prefix = [ cell(expense.id), date(expense.incurred_on), cell(expense.payee) ]
      rows = expense.line_items.map do |item|
        [ *prefix, cell(item.position + 1), cell(item.description), cell(item.category.presence || expense.category), money(item.amount_cents) ]
      end
      unless expense.remainder_cents.zero?
        label = rows.empty? ? expense.description : "Unitemized balance"
        rows << [ *prefix, {}, cell(label), cell(expense.category), money(expense.remainder_cents) ]
      end
      rows
    end
  end

  def category_rows
    summary = @register.summary
    [ *summary.fetch(:by_category), summary.merge(category: "Total") ].map do |row|
      [ cell(row.fetch(:category)), money(row.fetch(:total_cents)), money(row.fetch(:paid_cents)), money(row.fetch(:unpaid_cents)) ]
    end
  end

  def cell(value, format = nil)
    return {} if value.nil?
    type = value.is_a?(Numeric) ? :numberValue : :stringValue
    result = { userEnteredValue: { type => value } }
    result[:userEnteredFormat] = { numberFormat: format } if format
    result
  end

  def date(value) = value ? cell((value - DATE_EPOCH).to_i, DATE) : {}
  def money(cents) = cell(cents.fdiv(100), CURRENCY)
end
