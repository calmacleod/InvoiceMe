class InvoiceExport < ApplicationRecord
  belongs_to :invoice
  enum :status, %w[queued running retrying succeeded failed].index_with(&:itself), validate: true
  scope :active, -> { where(status: %w[queued running retrying]) }
  validates :step, inclusion: { in: %w[waiting validating finalizing document pdf ledger complete] }

  def self.enqueue_for(invoice)
    export = invoice.with_lock do
      existing = invoice.invoice_exports.active.first
      return existing if existing
      invoice.ensure_previewed_for_export!
      invoice.update!(publish_error: nil)
      invoice.invoice_exports.create!
    end
    begin
      job = ExportInvoiceJob.perform_later(export.id)
      raise ActiveJob::EnqueueError, "Export was not queued" unless job&.successfully_enqueued?
    rescue StandardError => error
      Rails.error.report(error)
      export.fail!("The export could not be queued. Try syncing again shortly.")
      raise GoogleApi::Error, export.error
    end
    export
  end

  def active? = queued? || running? || retrying?

  def progress
    as_json(only: %i[id status step attempts error retry_at finished_at]).merge(active: active?, max_attempts: ExportInvoiceJob::MAX_ATTEMPTS)
  end

  def fail!(message)
    update!(status: "failed", error: message, retry_at: nil, finished_at: Time.current)
    invoice.update!(publish_error: message)
  end
end
