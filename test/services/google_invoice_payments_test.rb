require "test_helper"
require_relative "../test_helpers/fake_google"

class GoogleInvoicePaymentsTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @season.update!(spreadsheet_id: "fictional-ledger")
    @api = FakeGoogle.new
    @deposit = Date.new(2024, 11, 15)
  end

  test "applies only the remaining balance from the original ledger destination" do
    invoice = invoice("Example")
    issued = invoice.published_at
    invoice.payments.create!(amount_cents: 1300, received_on: @deposit - 2, method: "Cheque")
    @season.update!(spreadsheet_id: "different-fictional-ledger", sheet_name: "Different tab")
    reads = []
    @api.define_singleton_method(:values) do |spreadsheet, range|
      reads << [ spreadsheet, range ]
      super(spreadsheet, range)
    end
    @api.rows[7] = row(invoice, (@deposit - Date.new(1899, 12, 30)).to_i)

    assert_equal({ checked_count: 1, imported_count: 1, review_count: 0, error: nil }, check)
    assert_equal [ [ "fictional-ledger", "'2026 invoices'!A3:I100" ] ], reads
    assert_equal "Paid", invoice.reload.status
    assert_equal issued, invoice.published_at
    assert_equal 3, invoice.ledger_row
    assert_equal [ 1374, @deposit, "E-transfer" ], invoice.payments.order(:id).last.values_at(:amount_cents, :received_on, :method)
    assert_equal 0, check.fetch(:imported_count)
    assert_empty @api.batches
  end

  test "skips partial payments and flags duplicates missing rows and inconsistent settlements" do
    partial = invoice("Partial")
    duplicate = invoice("Duplicate")
    inconsistent = invoice("Inconsistent")
    missing_metadata = invoice("Metadata")
    short = invoice("Short")
    missing = invoice("Missing")
    @api.rows[3] = row(partial).tap { |values| values[5, 2] = [ 10, 16.74 ] }
    @api.rows[4] = @api.rows[8] = row(duplicate)
    @api.rows[5] = row(inconsistent).tap { |values| values[4, 3] = [ 26, 26, 0 ] }
    @api.rows[6] = row(missing_metadata, "2024-02-30")
    @api.rows[7] = [ short.number ]

    assert_equal({ checked_count: 6, imported_count: 0, review_count: 4, error: nil }, check)
    [ partial, duplicate, inconsistent, missing_metadata, short, missing ].each do |record|
      assert_equal "Outstanding", record.reload.status
    end
  end

  test "never applies payments to drafts, pending exports or invoices with unpublished changes" do
    exporting = invoice("Exporting")
    exporting.invoice_exports.create!
    draft = invoice("Draft", publish: false)
    needs_sync = invoice("Needs-sync")
    needs_sync.update!(published_at: nil)
    [ exporting, draft, needs_sync ].each_with_index { |record, index| @api.rows[index + 3] = row(record) }

    assert_no_difference("Payment.count") { check }
  end

  private

  def invoice(suffix, publish: true)
    record = @season.invoices.create!(number: "2026_#{suffix}", recipient: "Example Club", description: "Fictional services",
      issued_on: "2024-11-01", line_items_attributes: [ { description: "Example", quantity: 2, rate: "13.37" } ])
    if publish
      record.finalize!
      record.update!(ledger_row: 3, published_at: Time.current)
    end
    record
  end

  def row(record, date = @deposit.iso8601)
    [ record.number, "", "", "", 26.74, 26.74, 0, "E-transfer", date ]
  end

  def check = GoogleInvoicePayments.new(@season, api: @api).call
end
