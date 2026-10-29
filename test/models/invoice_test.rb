require "test_helper"
class InvoiceTest < ActiveSupport::TestCase
  def setup
    @season = Season.create!(year: 2026, sheet_name: "2026 invoices", issuer: Season::DEFAULT_ISSUER)
    @invoice = @season.invoices.create!(number: "2026_16_Test", recipient: "Test club", description: "Season fees", issued_on: Date.current, line_items_attributes: [{description: "Officials", quantity: "2.5", rate: "100.25"}])
  end
  test "quantities multiply exact cents and round each line" do
    assert_equal 25_063, @invoice.total_cents
    assert_equal 25_063, @invoice.owed_cents
  end
  test "money rejects precision loss and malformed amounts" do
    ["10.005", "oops", "-1", "1e3"].each { |v| assert_raises(ArgumentError) { MoneyValue.cents(v) } }
    assert_equal 123456, MoneyValue.cents("$1,234.56")
  end
  test "invalid rate and empty invoice cannot save" do
    @invoice.line_items.first.rate = "bad"
    assert_not @invoice.save
    @invoice.reload
    @invoice.line_items.each(&:mark_for_destruction)
    assert_not @invoice.save
  end
  test "numbers are unique within year" do
    duplicate = @invoice.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:number], "has already been taken"
  end
  test "finalized invoice snapshots details and prevents editing" do
    @invoice.finalize!
    @season.update!(issuer: @season.issuer.merge("address" => "New address"))
    assert_equal Season::DEFAULT_ISSUER["address"], @invoice.reload.issuer["address"]
    assert_not @invoice.update(recipient: "Changed")
    @invoice.reload
    assert @invoice.update(private_notes: "Internal only")
  end
  test "payments track balance and reject overpayments" do
    assert_not @invoice.payments.build(amount_cents: 100, method: "Cheque", received_on: Date.current).valid?
    @invoice.payments.reset
    @invoice.finalize!
    @invoice.payments.create!(amount_cents: 10000, method: "Cheque", received_on: Date.current)
    assert_equal 15063, @invoice.owed_cents
    assert_not @invoice.payments.build(amount_cents: 15064, method: "Cheque", received_on: Date.current).valid?
  end
  test "loaded payment collection does not count an unsaved payment twice" do
    @invoice.finalize!
    @invoice.payments.load
    payment = @invoice.payments.build(amount_cents: 20000, method: "Cheque", received_on: Date.current)
    assert payment.valid?
    payment.save!
    assert_equal 5063, @invoice.owed_cents
  end
  test "quantities cannot silently lose precision and finalized line items are locked" do
    item = @invoice.line_items.first
    item.quantity = "1.0001"
    assert_not item.valid?
    @invoice.reload.finalize!
    assert_not @invoice.line_items.first.update(quantity: 5)
  end
  test "games cannot cross years" do
    other = Season.create!(year: 2027, sheet_name: "2027 invoices", issuer: Season::DEFAULT_ISSUER)
    game = other.games.create!(external_id: "1", date: Date.current)
    @invoice.games << game
    assert_not @invoice.valid?
  end
  test "document escapes input and excludes private notes" do
    @invoice.update!(recipient: "Club <script>alert(1)</script>", private_notes: "PRIVATE-SECRET")
    html = InvoiceDocument.new(@invoice).html
    assert_includes html, "&lt;script&gt;"
    assert_not_includes html, "PRIVATE-SECRET"
    pdf = InvoiceDocument.new(@invoice).pdf
    assert pdf.start_with?("%PDF-")
    Zip::File.open_buffer(InvoiceDocument.new(@invoice).odt) do |zip|
      content = zip.read("content.xml")
      assert Nokogiri::XML(content) { |config| config.strict }.errors.empty?
      assert_includes content, "&lt;script&gt;"
      assert_not_includes content, "PRIVATE-SECRET"
      assert zip.find_entry("Pictures/logo.jpg")
      assert_includes content, 'text:anchor-type="as-char"'
    end
  end
end
