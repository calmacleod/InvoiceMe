require "test_helper"
class InvoiceTest < ActiveSupport::TestCase
  def setup
    @season = seasons(:current)
    @invoice = @season.invoices.create!(number: "2026_16_Test", recipient: "Test club", description: "Season fees", issued_on: Date.current, line_items_attributes: [ { description: "Officials", quantity: "2.5", rate: "100.25" } ])
  end
  test "quantities multiply exact cents and round each line" do
    assert_equal 25_063, @invoice.total_cents
    assert_equal 25_063, @invoice.owed_cents
  end
  test "amount-only lines use a single charge and remain immutable after finalizing" do
    item = @invoice.line_items.create!(description: "Example travel", amount_only: true, rate: "24.75", position: 1)
    assert_equal 1, item.quantity
    assert_equal 2475, item.total_cents
    assert_equal 27538, @invoice.reload.total_cents
    item.quantity = 99
    assert_equal 2475, item.total_cents
    item.save!
    assert_equal 1, item.reload.quantity
    @invoice.finalize!
    assert_equal @invoice.total_cents, InvoiceTotals.new(@season.invoices).call[:invoiced]
    assert_not item.update(amount_only: false)
    assert_not @invoice.update(line_items_attributes: [ { id: item.id, description: item.description, rate: "24.75", position: 0 } ])
    [ "10.005", "bad", "-1" ].each do |rate|
      assert_not @invoice.line_items.build(description: "Example amount", amount_only: true, rate: rate).valid?
    end
  end
  test "money rejects precision loss and malformed amounts" do
    [ "10.005", "oops", "-1", "1e3" ].each { |v| assert_raises(ArgumentError) { MoneyValue.cents(v) } }
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
    original_address = @season.issuer["address"]
    @invoice.finalize!
    @season.update!(issuer: @season.issuer.merge("address" => "New address"))
    assert_equal original_address, @invoice.reload.issuer["address"]
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
  test "returning to draft unlocks details and lines while preserving the Google identity" do
    @invoice.finalize!
    @invoice.update!(google_doc_id: "example-doc", google_pdf_id: "example-pdf", ledger_row: 3, published_at: Time.current, publish_error: "Old example error")
    destination = @invoice.destination
    assert_not @invoice.update(finalized_at: nil)
    @invoice.reload.reopen!
    assert @invoice.reopened?
    assert_equal "Draft", @invoice.status
    assert_nil @invoice.published_at
    assert_nil @invoice.publish_error
    assert_nil @invoice.issuer_snapshot
    assert @invoice.google_doc_dirty?
    assert @invoice.google_pdf_dirty?
    assert_equal [ "example-doc", "example-pdf", 3 ], [ @invoice.google_doc_id, @invoice.google_pdf_id, @invoice.ledger_row ]
    assert @invoice.update(recipient: "Changed fictional club", line_items_attributes: [ { id: @invoice.line_items.first.id, description: "Revised fictional services", quantity: "3", rate: "100.25" } ])
    assert_equal 30_075, @invoice.reload.total_cents
    assert_not @invoice.update(number: "Different-number")
    @invoice.reload
    @season.update!(drive_folder_id: "different-folder", spreadsheet_id: "different-sheet", issuer: @season.issuer.merge("address" => "New fictional address"))
    @invoice.finalize!
    assert_equal destination, @invoice.destination
    assert_equal "New fictional address", @invoice.issuer["address"]
    assert_not @invoice.update(recipient: "Locked again")
  end
  test "reopening blocks active exports and recorded payments" do
    @invoice.finalize!
    %w[queued running retrying].each do |status|
      export = @invoice.invoice_exports.create!(status: status)
      assert_raises(GoogleApi::Error) { @invoice.reopen! }
      assert @invoice.reload.finalized_at
      export.destroy!
    end
    @invoice.payments.create!(amount_cents: 100, method: "Cheque", received_on: Date.current)
    error = assert_raises(GoogleApi::Error) { @invoice.reopen! }
    assert_includes error.message, "recorded payments"
    assert @invoice.reload.finalized_at
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

  test "contact names and emails are normalized validated and locked on finalization" do
    @invoice.update!(contacts: [ { name: " Fictional Avery ", email: " AVERY@EXAMPLE.TEST " }, { name: "", email: "" }, { name: "Fictional Rowan", email: "" } ])
    assert_equal [ { "name" => "Fictional Avery", "email" => "avery@example.test" }, { "name" => "Fictional Rowan", "email" => "" } ], @invoice.reload.contacts
    assert_equal "Fictional Avery, Fictional Rowan", @invoice.attention
    assert_equal "avery@example.test", @invoice.contact_email
    invalid = [ "invalid", [ "invalid" ], [ { name: "Example" } ], [ { name: "Example", email: "not-an-email" } ], [ { name: "avery@example.test", email: "" } ], [ { name: "x" * 201, email: "" } ] ]
    invalid.each { |contacts| assert_not @invoice.update(contacts: contacts), contacts.inspect }
    @invoice.reload.finalize!
    assert_not @invoice.update(contacts: [])
    assert_equal "avery@example.test", @invoice.reload.contact_email
  end

  test "legacy name email and combined contacts remain readable and explicit removal does not revive them" do
    {
      "Fictional Avery" => [ "Fictional Avery", "" ],
      "Fictional Avery <AVERY@EXAMPLE.TEST>" => [ "Fictional Avery", "avery@example.test" ],
      "avery@example.test" => [ @invoice.recipient, "avery@example.test" ]
    }.each do |legacy, (attention, email)|
      @invoice.update!(contact: legacy)
      assert_equal attention, @invoice.reload.attention
      assert_equal email, @invoice.contact_email
    end
    @invoice.update!(contacts: [])
    assert_empty @invoice.reload.contacts
    assert_equal @invoice.recipient, @invoice.attention
    assert_equal "", @invoice.contact_email
  end

  test "legacy contact lengths do not prevent finalized invoice bookkeeping" do
    @invoice.update!(contact: "Fictional Coordinator " * 12)
    @invoice.finalize!
    assert @invoice.update(private_notes: "Example reminder")
    assert_equal "", @invoice.contact_email
  end
end
