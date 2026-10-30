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
end
