class CheckInvoicePaymentsJob < ApplicationJob
  queue_as :google_exports

  def perform(check_id = nil, token = nil)
    return enqueue_seasons unless check_id

    check = InvoicePaymentCheck.find_by(id: check_id)
    return unless check

    GoogleLedger.with_lock do
      next unless check.reload.run_token == token && (check.queued? || check.running?)

      check.update!(status: "running")
      check.finish(token, **GoogleInvoicePayments.new(check.season).call)
    end
  rescue StandardError
    check&.finish(token, error: "The payment check stopped unexpectedly. Try again.")
    raise
  end

  private

  def enqueue_seasons
    return unless InvoicePaymentCheck.google_ready?

    Season.where(id: Invoice.published_in_ledger.select(:season_id)).find_each do |season|
      InvoicePaymentCheck.enqueue_for(season)
    rescue GoogleApi::Error => error
      Rails.error.report(error)
    end
  end
end
