class PublishInvoice
  def initialize(invoice, api: nil, progress: nil)
    @invoice, @api, @progress = invoice, api, progress
  end
  def call
    # Cross-process file lock avoids concurrent remote writes without holding a SQLite write transaction over HTTP.
    FileUtils.mkdir_p(Rails.root.join("storage/locks"))
    File.open(Rails.root.join("storage/locks/google-publish.lock"), "w") do |lock|
      lock.flock(File::LOCK_EX)
      @invoice.reload
      @invoice.ensure_previewed_for_export!
      @progress&.call("validating")
      destination = @invoice.destination
      raise GoogleApi::Error, "Set this year's Drive folder and master spreadsheet in Settings" unless destination["drive_folder_id"].present? && destination["spreadsheet_id"].present?
      @api ||= GoogleApi.new
      @api.validate_destination(destination)
      ledger = GoogleLedger.new(@api, destination)
      ledger.check_number_available!(@invoice) unless @invoice.ledger_row
      # Remote preflight can take time. Recheck under the same invoice lock used
      # by autosave before freezing the document, so late edits cannot disappear.
      @invoice.with_lock do
        @invoice.ensure_previewed_for_export!
        @progress&.call("finalizing")
        @invoice.finalize!
      end
      renderer = InvoiceDocument.new(@invoice)
      @progress&.call("document")
      if @invoice.google_doc_id.nil? || @invoice.google_doc_dirty?
        doc = @api.upload(name: @invoice.number, folder: destination.fetch("drive_folder_id"), mime: "application/vnd.oasis.opendocument.text", target_mime: "application/vnd.google-apps.document", bytes: renderer.odt, key: key("doc"), file_id: @invoice.google_doc_id, replace: @invoice.google_doc_dirty?)
        @invoice.update!(google_doc_id: doc, google_doc_dirty: false)
      end
      @progress&.call("pdf")
      if @invoice.google_pdf_id.nil? || @invoice.google_pdf_dirty?
        pdf = @api.upload(name: "#{@invoice.number}.pdf", folder: destination["pdf_folder_id"].presence || destination.fetch("drive_folder_id"), mime: "application/pdf", bytes: renderer.pdf, key: key("pdf"), file_id: @invoice.google_pdf_id, replace: @invoice.google_pdf_dirty?)
        @invoice.update!(google_pdf_id: pdf, google_pdf_dirty: false)
      end
      @progress&.call("ledger")
      GoogleLedger.new(@api, destination).sync(@invoice)
      @invoice.update!(published_at: Time.current, publish_error: nil)
    end
    @invoice
  rescue GoogleApi::Error => e
    @invoice.update!(publish_error: e.message)
    raise
  end
  private
  def key(kind)
    Digest::SHA256.hexdigest("#{@invoice.season_id}/#{@invoice.id}/#{@invoice.number}/#{kind}")
  end
end
