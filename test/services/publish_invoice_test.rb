require "test_helper"
require_relative "../test_helpers/fake_google"
class PublishInvoiceTest < ActiveSupport::TestCase
  def setup
    @season = seasons(:current)
    @season.update!(drive_folder_id: "folder", spreadsheet_id: "sheet")
    @invoice = @season.invoices.create!(number: "2026_Test", recipient: "Test", description: "Fees", issued_on: Date.current, line_items_attributes: [ { description: "Officials", quantity: 4, rate: "1000" } ])
    @api = FakeGoogle.new
  end
  test "publish creates doc pdf and ledger row with exact balance" do
    PublishInvoice.new(@invoice, api: @api).call
    assert_equal 2, @api.uploads.size
    assert_equal "application/vnd.google-apps.document", @api.uploads.first[:target_mime]
    assert_equal "application/vnd.oasis.opendocument.text", @api.uploads.first[:mime]
    assert_equal "application/pdf", @api.uploads.last[:mime]
    assert_equal 4000.0, @api.writes.first.last.first[4]
    assert_equal 3, @invoice.ledger_row
    assert @invoice.published_at
    PublishInvoice.new(@invoice, api: @api).call
    assert_equal 2, @api.uploads.size
    assert_equal 2, @api.writes.size
  end
  test "unpreviewed workbench changes cannot publish a stale invoice" do
    InvoiceDraft.create!(user: users(:one), season: @season, invoice: @invoice, client_key: "example-publish-guard", data: { "recipient" => "Changed fictional club" })
    error = assert_raises(GoogleApi::Error) { PublishInvoice.new(@invoice, api: @api).call }
    assert_includes error.message, "Save & preview"
    assert_nil @invoice.reload.finalized_at
    assert_empty @api.uploads
    assert_empty @api.writes
  end
  test "edits saved during Google preflight are checked again before finalization" do
    invoice, season, user = @invoice, @season, users(:one)
    @api.define_singleton_method(:validate_destination) do |_|
      InvoiceDraft.create!(user: user, season: season, invoice: invoice, client_key: "example-late-edit", data: { "recipient" => "Late fictional edit" })
      true
    end
    assert_raises(GoogleApi::Error) { PublishInvoice.new(@invoice, api: @api).call }
    assert_nil @invoice.reload.finalized_at
    assert_empty @api.uploads
    assert_empty @api.writes
  end
  test "retry after ledger failure reuses files and pending row" do
    @api.fail_write = true
    assert_raises(GoogleApi::Error) { PublishInvoice.new(@invoice, api: @api).call }
    assert @invoice.reload.finalized_at
    assert_equal 3, @invoice.ledger_row
    assert_nil @invoice.published_at
    @api.fail_write = false
    PublishInvoice.new(@invoice, api: @api).call
    assert_equal 2, @api.uploads.size
    assert_equal 1, @api.writes.size
  end
  test "existing invoice number is never overwritten" do
    @api.write_values("sheet", "range", [ [ "2026_Test", "existing" ] ])
    assert_raises(GoogleApi::Error) { PublishInvoice.new(@invoice, api: @api).call }
    assert_equal 1, @api.writes.size
    assert_nil @invoice.reload.finalized_at
    assert_empty @api.uploads
  end
  test "reopened invoices replace their documents and update the same ledger entry" do
    PublishInvoice.new(@invoice, api: @api).call
    original_ids = [ @invoice.google_doc_id, @invoice.google_pdf_id, @invoice.ledger_row ]
    @invoice.reopen!
    @invoice.update!(recipient: "Changed fictional club", line_items_attributes: [ { id: @invoice.line_items.first.id, description: "Revised fictional services", quantity: 2, rate: "1000" } ])
    PublishInvoice.new(@invoice, api: @api).call
    assert_equal original_ids, [ @invoice.google_doc_id, @invoice.google_pdf_id, @invoice.ledger_row ]
    assert_equal original_ids.first(2), @api.uploads.last(2).map { |upload| upload[:file_id] }
    assert @api.uploads.last(2).all? { |upload| upload[:replace] }
    Zip::File.open_buffer(@api.uploads[-2][:bytes]) do |zip|
      assert_includes zip.read("content.xml"), "Changed fictional club"
    end
    assert_equal 2000.0, @api.rows.fetch(3)[4]
    assert_equal 1, @api.rows.values.count { |row| row[0] == @invoice.number }
    assert_not @invoice.reload.google_doc_dirty?
    assert_not @invoice.google_pdf_dirty?
    PublishInvoice.new(@invoice, api: @api).call
    assert_equal 4, @api.uploads.size
  end
  test "a failed revised PDF resumes without replacing the completed revised Doc again" do
    PublishInvoice.new(@invoice, api: @api).call
    @invoice.reopen!
    @invoice.update!(description: "Revised fictional fees")
    @api.upload_error = GoogleApi::TransientError.new("Example PDF interruption")
    @api.fail_mime = "application/pdf"
    assert_raises(GoogleApi::TransientError) { PublishInvoice.new(@invoice, api: @api).call }
    assert_not @invoice.reload.google_doc_dirty?
    assert @invoice.google_pdf_dirty?
    assert_nil @invoice.published_at
    @api.upload_error = nil
    PublishInvoice.new(@invoice, api: @api).call
    assert_equal 2, @api.upload_calls.count { |upload| upload[:target_mime] == "application/vnd.google-apps.document" }
    assert_not @invoice.reload.google_pdf_dirty?
    assert @invoice.published_at
  end
end
