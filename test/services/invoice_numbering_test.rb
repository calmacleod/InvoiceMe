require "test_helper"
require_relative "../test_helpers/fake_google"

class InvoiceNumberingTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @season.update!(spreadsheet_id: "fictional-ledger", sheet_name: "Example's invoices")
    @api = FakeGoogle.new
    @api.rows[2] = [ "Invoice Number" ]
  end

  test "uses the numeric maximum across the entire ledger and local drafts with the ledger's padding" do
    @api.rows.merge!(3 => [ "2026_09_FictionalA" ], 4 => [ "2026_02_FictionalB" ], 7 => [ "2026_11_FictionalC" ],
      8 => [ "2025_999_OtherYear" ], 9 => [ "Unrelated note 9999" ], 12 => [ "2026_03_FictionalD" ])
    local = build_invoice("Local")
    local.number = "2026_14_Local"
    local.save!
    invoice = build_invoice("Club_Reference")
    assert InvoiceNumbering.new(invoice, api: @api).save
    assert_equal "2026_15_Club_Reference", invoice.number
    assert_equal 15, @season.reload.last_invoice_sequence
    assert_empty @api.writes
    assert_empty @api.uploads
  end

  test "two allocations prepared against the same ledger get different numbers and deletion does not reuse them" do
    @api.rows[3] = [ "2026_04_FictionalA" ]
    invoices = 2.times.map { build_invoice("SameSuffix") }
    allocators = invoices.map { |invoice| InvoiceNumbering.new(invoice, api: @api) }
    allocators.each { |allocator| assert allocator.prepare }
    allocators.each { |allocator| assert allocator.save }
    assert_equal %w[2026_05_SameSuffix 2026_06_SameSuffix], invoices.map(&:number)
    invoices.last.destroy!
    next_invoice = build_invoice("Next")
    assert InvoiceNumbering.new(next_invoice, api: @api).save
    assert_equal "2026_07_Next", next_invoice.number
  end

  test "numbers start at one in a new year and expand past the padding width" do
    invoice = build_invoice("First")
    assert InvoiceNumbering.new(invoice, api: @api).save
    assert_equal "2026_1_First", invoice.number
    @api.rows[3] = [ "2026_099_FictionalA" ]
    invoice = build_invoice("Next")
    assert InvoiceNumbering.new(invoice, api: @api).save
    assert_equal "2026_100_Next", invoice.number
  end

  test "editing a saved draft changes only the suffix without reading Google or consuming another sequence" do
    invoice = build_invoice("Original")
    assert InvoiceNumbering.new(invoice, api: @api).save
    invoice.number_suffix = "Revised_Info"
    @api.define_singleton_method(:values) { |*| raise "Google must not be called for edits" }
    assert InvoiceNumbering.new(invoice, api: @api).save
    assert_equal "2026_1_Revised_Info", invoice.reload.number
    assert_equal 1, @season.reload.last_invoice_sequence
    assert_not invoice.update(number: "2026_8_Revised_Info")
    invoice.reload.finalize!
    invoice.reopen!
    assert_not invoice.update(number_suffix: "Renamed")
  end

  test "invalid identifying info and invoice details consume no numbers and do not call Google" do
    @api.define_singleton_method(:values) { |*| raise "Invalid invoices must not read Google" }
    [ "", "Invalid/Info", "x" * 121 ].each do |suffix|
      assert_not InvoiceNumbering.new(build_invoice(suffix), api: @api).save
    end
    invoice = build_invoice("Example")
    invoice.recipient = ""
    assert_not InvoiceNumbering.new(invoice, api: @api).save
    assert_equal 0, @season.reload.last_invoice_sequence
    assert_equal 0, @season.invoices.count
  end

  test "inaccessible or misconfigured ledgers never fall back to a potentially used local number" do
    @api.rows[2] = [ "Wrong header" ]
    assert_raises(GoogleApi::Error) { InvoiceNumbering.new(build_invoice("Example"), api: @api).save }
    @api.define_singleton_method(:values) { |*| raise GoogleApi::TransientError, "Example outage" }
    assert_raises(GoogleApi::TransientError) { InvoiceNumbering.new(build_invoice("Example"), api: @api).save }
    @season.reload.update!(spreadsheet_id: nil)
    assert_raises(GoogleApi::Error) { InvoiceNumbering.new(build_invoice("Example"), api: @api).save }
    assert_equal 0, @season.reload.last_invoice_sequence
    assert_equal 0, @season.invoices.count
  end

  test "failed final validation rolls back the counter within an existing transaction" do
    invoice = build_invoice("Example")
    numbering = InvoiceNumbering.new(invoice, api: @api)
    assert numbering.prepare
    invoice.recipient = ""
    Invoice.transaction { assert_not numbering.save }
    assert_equal 0, @season.reload.last_invoice_sequence
    assert_equal 0, @season.invoices.count
  end

  private

  def build_invoice(suffix)
    @season.invoices.new(number_suffix: suffix, recipient: "Fictional Club", description: "Fictional services", issued_on: "2031-09-15",
      line_items_attributes: [ { description: "Fictional services", quantity: 1, rate: "13.37" } ])
  end
end
