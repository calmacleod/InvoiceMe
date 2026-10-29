class PublishInvoice
  def initialize(invoice, api: nil)
    @invoice, @api = invoice, api
  end
  def call
    # Cross-process file lock avoids concurrent remote writes without holding a SQLite write transaction over HTTP.
    FileUtils.mkdir_p(Rails.root.join("storage/locks"))
    File.open(Rails.root.join("storage/locks/google-publish.lock"), "w") do |lock|
      lock.flock(File::LOCK_EX)
      @invoice.reload
      destination = @invoice.destination
      raise GoogleApi::Error, "Set this year's Drive folder and master spreadsheet in Settings" unless destination["drive_folder_id"].present? && destination["spreadsheet_id"].present?
      @api ||= GoogleApi.new
      @api.validate_destination(destination)
      check_number_available(destination) unless @invoice.ledger_row
      @invoice.finalize!
      renderer = InvoiceDocument.new(@invoice)
      doc = @invoice.google_doc_id || @api.upload(name: @invoice.number, folder: destination.fetch("drive_folder_id"), mime: "application/vnd.oasis.opendocument.text", target_mime: "application/vnd.google-apps.document", bytes: renderer.odt, key: key("doc"))
      @invoice.update!(google_doc_id: doc)
      pdf = @invoice.google_pdf_id || @api.upload(name: "#{@invoice.number}.pdf", folder: destination["pdf_folder_id"].presence || destination.fetch("drive_folder_id"), mime: "application/pdf", bytes: renderer.pdf, key: key("pdf"))
      @invoice.update!(google_pdf_id: pdf)
      sync_ledger(destination)
      @invoice.update!(published_at: Time.current, publish_error: nil)
    end
    @invoice
  rescue GoogleApi::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError => e
    @invoice.update!(publish_error: e.message)
    raise GoogleApi::Error, e.message
  end
  private
  def check_number_available(destination)
    tab = "'#{destination.fetch('sheet_name').gsub("'", "''")}'"
    rows = @api.values(destination.fetch("spreadsheet_id"), "#{tab}!A#{destination.fetch('ledger_start_row')}:I100000")
    raise GoogleApi::Error, "Invoice number already exists in the master sheet. Choose a different invoice number before publishing." if rows.any? { |r| r[0].to_s == @invoice.number }
  end
  def key(kind)
    Digest::SHA256.hexdigest("#{@invoice.season_id}/#{@invoice.id}/#{@invoice.number}/#{kind}")
  end
  def sync_ledger(destination)
    tab = "'#{destination.fetch('sheet_name').gsub("'", "''")}'"
    spreadsheet = destination.fetch("spreadsheet_id")
    start = destination.fetch("ledger_start_row").to_i
    # Scan only the invoice ledger. Refuse ambiguous existing invoice numbers instead of overwriting them.
    rows = @api.values(spreadsheet, "#{tab}!A#{start}:I100000")
    matches = rows.each_index.select { |i| rows[i][0].to_s == @invoice.number }
    raise GoogleApi::Error, "Invoice number appears more than once in the master sheet" if matches.size > 1
    row = matches.first && matches.first + start
    if row && !@invoice.ledger_row
      raise GoogleApi::Error, "Invoice number already exists in the master sheet. Resolve it before publishing."
    end
    if @invoice.ledger_row && !row && @invoice.published_at
      raise GoogleApi::Error, "The invoice's ledger row was removed or renamed. Check the master sheet."
    end
    row ||= @invoice.ledger_row || start + (rows.rindex { |r| r.first(5).any?(&:present?) } || -1) + 1
    # Persist intent before PUT; retry verifies the number and writes the same row.
    @invoice.update!(ledger_row: row)
    current = @api.values(spreadsheet, "#{tab}!A#{row}:I#{row}").first || []
    raise GoogleApi::Error, "The target ledger row is occupied" if current[0].present? && current[0] != @invoice.number
    payment = @invoice.payments.order(:received_on, :id).last
    values = [@invoice.number, @invoice.issued_on.iso8601, @invoice.description, @invoice.contact.to_s, @invoice.total_cents / 100.0, @invoice.received_cents / 100.0, @invoice.owed_cents / 100.0, payment&.method.to_s, payment&.received_on&.iso8601.to_s]
    @api.write_values(spreadsheet, "#{tab}!A#{row}:I#{row}", [values])
  end
end
