class InvoiceNumbering
  def self.sequence(number, year)
    number.to_s.strip.match(/\A#{year}_(\d+)(?:_|\z)/)&.[](1)&.to_i || 0
  end

  # Workbenches saved before automatic numbering may still contain a full number.
  def self.suffix(number, year)
    number.to_s.sub(/\A#{year}_(?:\d+_)?/, "")
  end

  def initialize(invoice, api: nil)
    @invoice, @season, @api = invoice, invoice.season, api
  end

  def save
    return @invoice.save if @invoice.persisted?
    return false unless prepare

    saved = false
    Season.transaction(requires_new: true) do
      # The first statement is a write so SQLite serializes allocations before
      # we read the counter/local invoices, even for simultaneous workbenches.
      Season.where(id: @season.id).update_all("last_invoice_sequence = last_invoice_sequence + 1")
      @season.reload
      sequence = [ @season.last_invoice_sequence, local_maximum + 1, @ledger_maximum + 1 ].max
      @season.update!(last_invoice_sequence: sequence)
      assign_number(sequence)
      saved = @invoice.save
      raise ActiveRecord::Rollback unless saved
    end
    saved
  end

  # Fetch Google before entering the workbench's database transaction. Invalid
  # forms and autosaves need no Google request and never consume a number.
  def prepare
    return true if @ledger_maximum

    @invoice.number_suffix = @invoice.number_suffix.to_s.strip
    assign_number([ @season.last_invoice_sequence, local_maximum ].max + 1)
    return false unless @invoice.valid?

    numbers = ledger_numbers
    @ledger_maximum = numbers.map { |number| self.class.sequence(number, @season.year) }.max || 0
    @width = numbers.filter_map { |number| number.to_s.strip.match(/\A#{@season.year}_(0\d+)(?:_|\z)/)&.[](1)&.length }.max || 1
    true
  end

  private

  def assign_number(sequence)
    @invoice.number = "#{@season.year}_#{sequence.to_s.rjust(@width || 1, '0')}_#{@invoice.number_suffix}"
  end

  def local_maximum
    @season.invoices.pluck(:number).map { |number| self.class.sequence(number, @season.year) }.max || 0
  end

  def ledger_numbers
    raise GoogleApi::Error, "Set this year's master spreadsheet in Settings to assign invoice numbers." if @season.spreadsheet_id.blank?

    api = @api || GoogleApi.new
    tab = "'#{@season.sheet_name.gsub("'", "''")}'"
    rows = api.values(@season.spreadsheet_id, "#{tab}!A#{@season.ledger_start_row - 1}:A")
    unless rows.first&.first.to_s.downcase.gsub(/[^a-z]/, "") == "invoicenumber"
      raise GoogleApi::Error, "The master sheet's Invoice Number header was not found. Check the tab and first data row in Settings."
    end
    rows.drop(1).map(&:first)
  end
end
