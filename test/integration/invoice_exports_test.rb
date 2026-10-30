require "test_helper"

class InvoiceExportsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as(users(:one))
    @invoice = seasons(:current).invoices.create!(number: "2026_Example", recipient: "Example Club", description: "Fictional services", issued_on: Date.new(2026, 9, 15),
      line_items_attributes: [ { description: "Fictional services", quantity: 1, rate: "13.37" } ])
  end

  test "publishing queues one job and returns without making Google requests or finalizing" do
    assert_enqueued_with(job: ExportInvoiceJob, args: ->(args) { args == [ InvoiceExport.last.id ] }) do
      assert_difference "InvoiceExport.count", 1 do
        post publish_invoice_path(@invoice)
        post publish_invoice_path(@invoice)
      end
    end
    assert_redirected_to invoice_path(@invoice)
    assert_nil @invoice.reload.finalized_at
    assert_nil @invoice.google_doc_id
    assert @invoice.invoice_exports.first.queued?
    assert_equal 1, enqueued_jobs.count { |job| job[:job] == ExportInvoiceJob }
  end

  test "progress polling is authenticated and returns only progress without invoice content" do
    export = @invoice.invoice_exports.create!(status: "retrying", step: "document", attempts: 2, error: "Google returned HTTP 500", retry_at: 30.seconds.from_now)
    assert_no_enqueued_jobs do
      get invoice_path(@invoice), headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Show", "X-Inertia-Partial-Data" => "google_export")
    end
    assert_response :success
    props = response.parsed_body.fetch("props")
    assert_equal export.id, props.dig("google_export", "id")
    assert_equal "retrying", props.dig("google_export", "status")
    assert_equal "document", props.dig("google_export", "step")
    assert_equal 2, props.dig("google_export", "attempts")
    assert props.dig("google_export", "active")
    refute props.key?("invoice")
    refute_includes response.body, "Fictional services"
    sign_out
    get invoice_path(@invoice), headers: inertia_headers
    assert_redirected_to new_session_path
    assert_no_enqueued_jobs { post publish_invoice_path(@invoice) }
    assert_redirected_to new_session_path
  end

  test "unsaved workbench changes cannot enqueue a stale preview" do
    InvoiceDraft.create!(user: users(:one), season: @invoice.season, invoice: @invoice, client_key: "example-export", data: { "recipient" => "Changed fictional club" })
    assert_no_enqueued_jobs do
      assert_no_difference "InvoiceExport.count" do
        post publish_invoice_path(@invoice)
      end
    end
    assert_includes flash[:alert], "Save & preview"
  end

  test "active exports block edits deletion and workbench saves but retain private note editing" do
    draft = InvoiceDraft.create!(user: users(:one), season: @invoice.season, invoice: @invoice, client_key: "example-queued-export", data: {})
    @invoice.invoice_exports.create!
    patch invoice_path(@invoice), params: { invoice: { recipient: "Changed fictional recipient" } }
    assert_equal "Example Club", @invoice.reload.recipient
    assert_no_difference "Invoice.count" do
      delete invoice_path(@invoice)
    end
    post invoice_drafts_path, params: { invoice_id: @invoice.id }
    assert_redirected_to invoice_path(@invoice)
    patch invoice_draft_path(draft), params: { lock_version: draft.lock_version, data: { recipient: "Another fictional recipient" } }, as: :json
    assert_response :conflict
    assert_empty draft.reload.data
    post preview_invoice_draft_path(draft), params: { lock_version: draft.lock_version }
    assert_redirected_to invoice_path(@invoice)
    patch notes_invoice_path(@invoice), params: { private_notes: "Fictional private reminder" }
    assert_equal "Fictional private reminder", @invoice.reload.private_notes
  end

  test "payments wait for an active export so the ledger cannot be marked synced with a stale balance" do
    @invoice.finalize!
    export = @invoice.invoice_exports.create!
    assert_no_difference "Payment.count" do
      post payment_invoice_path(@invoice), params: { amount: "1.00", received_on: "2026-10-30", payment_method: "Cheque" }
    end
    assert_includes flash[:alert], "Wait for the Google export"
    export.fail!("Fictional failure")
    assert_difference "Payment.count", 1 do
      post payment_invoice_path(@invoice), params: { amount: "1.00", received_on: "2026-10-30", payment_method: "Cheque" }
    end
  end

  test "queue failures are visible and allow a subsequent explicit retry" do
    original = ExportInvoiceJob.method(:perform_later)
    ExportInvoiceJob.define_singleton_method(:perform_later) { |*| false }
    post publish_invoice_path(@invoice)
    assert @invoice.invoice_exports.last.failed?
    assert_includes flash[:alert], "could not be queued"
    assert_nil @invoice.reload.finalized_at
    ExportInvoiceJob.define_singleton_method(:perform_later, original)
    assert_enqueued_with(job: ExportInvoiceJob) { post publish_invoice_path(@invoice) }
    assert_equal 2, @invoice.invoice_exports.count
  ensure
    ExportInvoiceJob.define_singleton_method(:perform_later, original)
  end

  private

  def inertia_headers
    { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
  end
end
