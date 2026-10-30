class ExportInvoiceJob < ApplicationJob
  MAX_ATTEMPTS = 5
  RETRY_DELAYS = [ 10.seconds, 30.seconds, 2.minutes, 5.minutes ].freeze
  queue_as :google_exports

  def perform(export_id)
    export_id = Integer(export_id)
    @export = InvoiceExport.find_by(id: export_id)
    return unless @export
    # A redelivered job can resume a running export after a worker restart.
    # The file lock distinguishes it from a duplicate delivery to a live worker.
    FileUtils.mkdir_p(Rails.root.join("storage/locks"))
    File.open(Rails.root.join("storage/locks/export-#{export_id}.lock"), "w") do |lock|
      return unless lock.flock(File::LOCK_EX | File::LOCK_NB)
      perform_export
    end
  end

  private

  def perform_export
    claimed = @export.with_lock do
      next false unless @export.active?
      next false if @export.retry_at&.future?
      if @export.attempts >= MAX_ATTEMPTS
        @export.fail!("The export could not finish after #{MAX_ATTEMPTS} attempts. Your completed steps are retained. Try syncing again.")
        next false
      end
      @export.update!(status: "running", attempts: @export.attempts + 1, retry_at: nil, error: nil)
      true
    end
    return unless claimed

    PublishInvoice.new(@export.invoice, progress: ->(step) { @export.update!(step: step) }).call
    @export.update!(status: "succeeded", step: "complete", error: nil, finished_at: Time.current)
  rescue GoogleApi::TransientError => error
    retry_export(error)
  rescue GoogleApi::Error => error
    @export.fail!(error.message)
  rescue StandardError
    @export&.fail!("The export stopped unexpectedly. Your invoice and completed steps are retained. Try syncing again.")
    raise
  end

  def retry_export(error)
    return @export.fail!(error.message) if @export.attempts >= MAX_ATTEMPTS
    delay = RETRY_DELAYS.fetch(@export.attempts - 1) * (1 + rand * 0.15)
    retry_at = Time.current + delay
    @export.update!(status: "retrying", error: error.message, retry_at: retry_at)
    begin
      job = retry_job(wait_until: retry_at, error: error)
      raise ActiveJob::EnqueueError, "Retry was not queued" unless job&.successfully_enqueued?
    rescue StandardError => enqueue_error
      Rails.error.report(enqueue_error)
      @export.fail!("The next attempt could not be queued. Your completed steps are retained. Try syncing again.")
    end
  end
end
