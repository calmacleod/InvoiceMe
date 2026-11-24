class GoogleInvoicePayments
  SHEETS_EPOCH = Date.new(1899, 12, 30)

  def initialize(season, api: nil)
    @season, @api = season, api
  end

  def call
    invoices = @season.invoices.published_in_ledger.includes(:line_items, :payments).select { |invoice| invoice.owed_cents.positive? }
    counts = { checked_count: 0, imported_count: 0, review_count: 0 }
    error = nil
    invoices.group_by { |invoice| ledger_destination(invoice) }.each do |destination, records|
      raise GoogleApi::Error, "An invoice is missing its Google spreadsheet destination." if destination["spreadsheet_id"].blank?

      @api ||= GoogleApi.new
      @api.validate_ledger_headers(destination)
      rows = GoogleLedger.new(@api, destination).payment_rows(records.map(&:number).to_set)
      records.each do |invoice|
        result = check_payment(invoice, destination, rows[invoice.number])
        counts[:checked_count] += 1
        counts[:imported_count] += 1 if result == :imported
        counts[:review_count] += 1 if result == :review
      end
    rescue GoogleApi::Error => destination_error
      error ||= destination_error.message
    end
    counts.merge(error: error)
  end

  private

  def check_payment(invoice, destination, row)
    return :review unless row

    invoiced, received, owed = row[4, 3].to_a.map { |value| cents(value) }
    return unless received&.positive? && (owed == 0 || (invoiced && received >= invoiced))
    return :review unless invoiced == invoice.total_cents && received == invoiced && owed == 0

    method = row[7].strip if row[7].is_a?(String)
    received_on = deposit_date(row[8])
    return :review if method.blank? || !received_on || received_on > Date.current

    invoice.with_lock do
      next unless invoice.finalized_at && invoice.published_at && invoice.ledger_row && !invoice.exporting?
      next unless ledger_destination(invoice) == destination && invoice.total_cents == received && invoice.owed_cents.positive?

      invoice.payments.create!(amount_cents: invoice.owed_cents, method: method, received_on: received_on,
        notes: "Imported from the Google invoice ledger.")
      :imported
    end
  end

  def ledger_destination(invoice)
    invoice.destination.slice("spreadsheet_id", "sheet_name", "ledger_start_row")
  end

  def cents(value)
    (BigDecimal(value.to_s) * 100).round if value.is_a?(Numeric) && value.finite?
  end

  def deposit_date(value)
    if value.is_a?(Numeric) && value.finite? && value.between?(1, (Date.current - SHEETS_EPOCH).to_i)
      SHEETS_EPOCH + value.floor
    elsif value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.iso8601(value)
    end
  rescue Date::Error
    nil
  end
end
