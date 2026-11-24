class InvoicePaymentCheck < ApplicationRecord
  belongs_to :season
  enum :status, %w[idle queued running succeeded failed].index_with(&:itself), validate: true

  def self.google_ready? = GoogleApi.configured? && GoogleConnection.exists?

  def self.for_season(season)
    (season.invoice_payment_check || season.build_invoice_payment_check).progress
  end

  def self.enqueue_for(season)
    raise GoogleApi::Error, "Connect the treasurer Google account in Settings first." unless google_ready?

    token = SecureRandom.uuid
    check = season.with_lock do
      check = season.invoice_payment_check || season.build_invoice_payment_check
      return check if check.active?

      check.update!(status: "queued", run_token: token, error: nil, checked_count: 0, imported_count: 0, review_count: 0)
      check
    end
    begin
      job = CheckInvoicePaymentsJob.perform_later(check.id, token)
      raise ActiveJob::EnqueueError, "Payment check was not queued" unless job&.successfully_enqueued?
    rescue StandardError => error
      Rails.error.report(error)
      message = "The payment check could not be queued. Try again shortly."
      check.finish(token, error: message)
      raise GoogleApi::Error, message
    end
    check.reload
  end

  def active? = (queued? || running?) && updated_at > 15.minutes.ago

  def finish(token, error: nil, **counts)
    with_lock do
      next unless run_token == token

      update!(status: error ? "failed" : "succeeded", error: error, finished_at: Time.current, **counts)
    end
  end

  def progress
    interrupted = (queued? || running?) && !active?
    as_json(only: %i[status checked_count imported_count review_count finished_at error]).merge(
      "ready" => self.class.google_ready?, "active" => active?,
      "status" => interrupted ? "failed" : status,
      "error" => interrupted ? "The payment check did not finish. Try again." : error
    )
  end
end
