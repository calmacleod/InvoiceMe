require "test_helper"
require_relative "../test_helpers/fake_google"

class ExportInvoiceJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    season = seasons(:current)
    season.update!(drive_folder_id: "example-folder", spreadsheet_id: "example-sheet")
    @invoice = season.invoices.create!(number: "2026_Example", recipient: "Example Club", description: "Fictional fees", issued_on: Date.new(2026, 9, 15),
      line_items_attributes: [ { description: "Example services", quantity: 2, rate: "13.37" } ])
    @export = @invoice.invoice_exports.create!
    @api = FakeGoogle.new
    @original_google = GoogleApi.method(:new)
    api = @api
    GoogleApi.define_singleton_method(:new) { |*| api }
  end

  teardown do
    GoogleApi.define_singleton_method(:new, @original_google)
  end

  test "background export records progress and completes all steps" do
    observed = []
    @api.define_singleton_method(:upload) do |**attrs|
      observed << InvoiceExport.find_by!(status: "running").step
      super(**attrs)
    end
    ExportInvoiceJob.perform_now(@export.id)
    assert @export.reload.succeeded?
    assert_equal "complete", @export.step
    assert_equal %w[document pdf], observed
    assert_equal 1, @export.attempts
    assert @export.finished_at
    assert @invoice.reload.published_at
    assert_equal 2, @api.uploads.size
    assert_equal 1, @api.writes.size
    assert_no_enqueued_jobs

    ExportInvoiceJob.perform_now(@export.id)
    assert_equal 2, @api.uploads.size
    assert_equal 1, @api.writes.size
  end

  test "a transient PDF failure schedules a retry that reuses the completed document" do
    @api.upload_error = GoogleApi::TransientError.new("Google returned HTTP 500 while uploading the PDF")
    @api.fail_mime = "application/pdf"
    assert_enqueued_with(job: ExportInvoiceJob, args: [ @export.id ]) { ExportInvoiceJob.perform_now(@export.id) }
    assert @export.reload.retrying?
    assert_equal "pdf", @export.step
    assert_equal 1, @export.attempts
    assert_includes @export.error, "HTTP 500"
    assert @invoice.reload.google_doc_id
    assert_nil @invoice.google_pdf_id
    assert_nil @invoice.published_at
    assert_operator @export.retry_at, :>=, 10.seconds.from_now - 1.second
    assert_operator @export.retry_at, :<=, 12.seconds.from_now

    @api.upload_error = nil
    travel_to(@export.retry_at + 1.second) { ExportInvoiceJob.perform_now(@export.id) }
    assert @export.reload.succeeded?
    assert_equal 2, @export.attempts
    assert_nil @export.error
    assert_nil @export.retry_at
    assert_nil @invoice.reload.publish_error
    assert_equal 2, @api.uploads.size
    assert_equal 1, @api.writes.size
  end

  test "a lost ledger acknowledgement retries the same row without recreating files" do
    @api.after_write_error = GoogleApi::TransientError.new("Google connection interrupted")
    ExportInvoiceJob.perform_now(@export.id)
    assert @export.reload.retrying?
    assert_equal "ledger", @export.step
    row = @invoice.reload.ledger_row
    assert row
    assert_equal 2, @api.uploads.size
    assert_equal 1, @api.writes.size

    @api.after_write_error = nil
    travel_to(@export.retry_at + 1.second) { ExportInvoiceJob.perform_now(@export.id) }
    assert @export.reload.succeeded?
    assert_equal row, @invoice.reload.ledger_row
    assert_equal 2, @api.uploads.size
    assert_equal @api.writes.first, @api.writes.last
  end

  test "temporary failures stop after five attempts and can be manually requeued" do
    @api.write_error = GoogleApi::TransientError.new("Google returned HTTP 503")
    5.times do |index|
      travel_to(@export.reload.retry_at ? @export.retry_at + 1.second : Time.current) { ExportInvoiceJob.perform_now(@export.id) }
      assert_equal index + 1, @export.reload.attempts
      assert_equal(index < 4 ? "retrying" : "failed", @export.status)
    end
    assert_equal 4, enqueued_jobs.count { |job| job[:job] == ExportInvoiceJob }
    assert_nil @export.retry_at
    assert @export.finished_at
    assert_nil @invoice.reload.published_at
    assert_equal "Google returned HTTP 503", @invoice.publish_error

    assert_enqueued_with(job: ExportInvoiceJob) { InvoiceExport.enqueue_for(@invoice) }
    assert_equal 2, @invoice.invoice_exports.count
  end

  test "permission and validation failures stop without automatic retries" do
    @api.upload_error = GoogleApi::Error.new("Google returned HTTP 403: check permissions")
    assert_no_enqueued_jobs { ExportInvoiceJob.perform_now(@export.id) }
    assert @export.reload.failed?
    assert_equal 1, @export.attempts
    assert_nil @export.retry_at
    assert_includes @export.error, "permissions"
  end

  test "unexpected failures leave an actionable terminal state and remain visible to the queue" do
    @api.upload_error = RuntimeError.new("Fictional internal exception")
    assert_raises(RuntimeError) { ExportInvoiceJob.perform_now(@export.id) }
    assert @export.reload.failed?
    assert_includes @export.error, "stopped unexpectedly"
    assert_not_includes @export.error, "Fictional internal exception"
  end

  test "an early duplicate delivery cannot bypass a scheduled retry" do
    @export.update!(status: "retrying", attempts: 1, retry_at: 1.minute.from_now)
    assert_no_enqueued_jobs { ExportInvoiceJob.perform_now(@export.id) }
    assert @export.reload.retrying?
    assert_equal 1, @export.attempts
    assert_empty @api.uploads
  end

  test "a redelivered export resumes after its worker releases the lock" do
    @export.update!(status: "running", attempts: 1)
    ExportInvoiceJob.perform_now(@export.id)
    assert @export.reload.succeeded?
    assert_equal 2, @export.attempts
  end

  test "a duplicate delivery to a live export does not perform remote writes" do
    @export.update!(status: "running", attempts: 1)
    FileUtils.mkdir_p(Rails.root.join("storage/locks"))
    File.open(Rails.root.join("storage/locks/export-#{@export.id}.lock"), "w") do |lock|
      lock.flock(File::LOCK_EX)
      ExportInvoiceJob.perform_now(@export.id)
    end
    assert @export.reload.running?
    assert_equal 1, @export.attempts
    assert_empty @api.uploads
  end

  test "a failure to schedule a retry becomes a terminal failure" do
    @api.write_error = GoogleApi::TransientError.new("Google returned HTTP 500")
    job = ExportInvoiceJob.new(@export.id)
    job.define_singleton_method(:retry_job) { |**| false }
    job.perform_now
    assert @export.reload.failed?
    assert_includes @export.error, "next attempt could not be queued"
    assert_nil @export.retry_at
  end
end
