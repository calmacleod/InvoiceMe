require "test_helper"

class InvoiceExportsSystemTest < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1100 ]

  setup do
    @invoice = seasons(:current).invoices.create!(number: "2026_Example", recipient: "Example Club", description: "Fictional services", issued_on: Date.new(2026, 9, 15),
      line_items_attributes: [ { description: "Fictional services", quantity: 1, rate: "13.37" } ])
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1", text: "Invoices."
  end

  test "invoice page polls retries and completion while preserving entered notes" do
    visit invoice_path(@invoice)
    accept_confirm { click_button "Finalize & save to Google" }
    assert_text "Queued for Google"
    assert_button "Export in progress…", disabled: true
    export = @invoice.invoice_exports.last
    assert export.queued?
    page.refresh
    assert_text "Queued for Google"
    fill_in "Private notes", with: "Unsaved fictional reminder"

    export.update!(status: "retrying", step: "document", attempts: 1, error: "Google returned HTTP 500 while creating the Google Doc", retry_at: 30.seconds.from_now)
    assert_text "Waiting to retry Google", wait: 8
    assert_text "Next attempt around"
    assert_text "Attempt 1 of 5"
    assert_field "Private notes", with: "Unsaved fictional reminder"

    @invoice.finalize!
    @invoice.update!(google_doc_id: "example-doc", google_pdf_id: "example-pdf", ledger_row: 3, published_at: Time.current)
    export.update!(status: "succeeded", step: "complete", error: nil, retry_at: nil, finished_at: Time.current)
    assert_text "Google export completed", wait: 8
    assert_link "Open Google Doc", href: "https://docs.google.com/document/d/example-doc/edit", wait: 8
    assert_link "Open Drive PDF", href: "https://drive.google.com/file/d/example-pdf/view"
    assert_button "Sync to Google", disabled: false
    assert_field "Private notes", with: "Unsaved fictional reminder"
    assert_no_text "Google returned HTTP 500"
  end

  test "terminal failures stop polling and offer another background export" do
    @invoice.finalize!
    export = @invoice.invoice_exports.create!(status: "running", step: "pdf", attempts: 5)
    visit invoice_path(@invoice)
    assert_button "Export in progress…", disabled: true
    export.fail!("Google returned HTTP 500 while uploading the PDF")
    assert_text "Google export needs attention", wait: 8
    assert_text "completed steps are retained"
    click_button "Retry Google export"
    assert_text "Queued for Google"
    assert_button "Export in progress…", disabled: true
    assert_equal 2, @invoice.invoice_exports.count
  end
end
