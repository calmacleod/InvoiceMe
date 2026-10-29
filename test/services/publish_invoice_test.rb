require "test_helper"
class PublishInvoiceTest < ActiveSupport::TestCase
  class FakeGoogle
    attr_reader :uploads, :writes
    attr_accessor :fail_write
    def initialize
      @uploads, @writes, @row = [], [], nil
    end
    def upload(**attrs)
      @uploads << attrs
      "file-#{@uploads.size}"
    end
    def validate_destination(_) = true
    def values(_, range)
      return @row ? [@row] : [] if range.include?("I100000")
      @row ? [@row] : []
    end
    def write_values(_, range, values)
      raise GoogleApi::Error, "Network failed" if @fail_write
      @writes << [range, values]
      @row = values.first
    end
  end
  def setup
    @season = Season.create!(year: 2026, sheet_name: "2026 invoices", issuer: Season::DEFAULT_ISSUER, drive_folder_id: "folder", spreadsheet_id: "sheet")
    @invoice = @season.invoices.create!(number: "2026_Test", recipient: "Test", description: "Fees", issued_on: Date.current, line_items_attributes: [{description: "Officials", quantity: 4, rate: "1000"}])
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
    @api.write_values("sheet", "range", [["2026_Test", "existing"]])
    assert_raises(GoogleApi::Error) { PublishInvoice.new(@invoice, api: @api).call }
    assert_equal 1, @api.writes.size
    assert_nil @invoice.reload.finalized_at
    assert_empty @api.uploads
  end
end
