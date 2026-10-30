require "test_helper"
require "pdf/reader"

class InvoiceDocumentTest < ActiveSupport::TestCase
  setup do
    @invoice = seasons(:current).invoices.build(
      number: "2026_Example", recipient: "Example University", description: "Season support",
      issued_on: Date.new(2026, 9, 15), private_notes: "INTERNAL ONLY",
      line_items_attributes: [
        { description: "Exhibition support", quantity: 1, rate: "250" },
        { description: "Season support", quantity: 4, rate: "400" },
        { description: "Travel", quantity: 1, rate: "20" }
      ]
    )
  end

  test "downloaded invoice has balanced table margins and keeps all text printable" do
    reader = pdf_reader

    assert_equal 1, reader.page_count
    assert_printable_layout reader
    text = reader.pages.first.text
    assert_includes text, "FINAL INVOICE FOR Example University 2026"
    assert_includes text, "$1870.00"
    assert_includes text, "TOTAL PAYABLE"
    assert_not_includes text, "INTERNAL ONLY"
  end

  test "wrapped headings and addresses stay within the invoice margins" do
    @invoice.issuer_snapshot = @invoice.issuer.merge(
      "name" => "Example Regional Tackle Football Officials and Community Sports Association"
    )
    @invoice.recipient = "Example University Athletics, Recreation and Community Sports Administration Department"
    @invoice.contact = "Example Coordinator"
    @invoice.recipient_address = "456 Fictional Avenue\nExample Town, ON\nB2B 2B2"
    @invoice.due_on = Date.new(2026, 10, 15)
    @invoice.public_notes = "Please include the invoice number when submitting payment."

    reader = pdf_reader
    assert_printable_layout reader
    runs = reader.pages.first.runs
    heading_tail = runs.find { |run| run.text.include?("Administration Department 2026") }
    metadata = runs.find { |run| run.text.include?("Invoice date:") }
    assert_operator heading_tail.y - metadata.endy, :>=, 10
    text = reader.pages.map(&:text).join(" ").gsub(/\s+/, " ")
    assert_includes text, @invoice.issuer.fetch("name").upcase
    assert_includes text, @invoice.recipient
    assert_includes text, "ATTENTION: Example Coordinator"
    assert_includes text, @invoice.public_notes
    signoff = reader.pages.last.text
    assert_includes signoff, "Thank you."
    assert_includes signoff, "Example Treasurer"
    assert_includes signoff, "Treasurer, EOTFOA"
    assert_includes signoff, "treasurer@example.test"
  end

  test "continued item tables retain balanced margins on every page" do
    @invoice.line_items.clear
    40.times do |index|
      @invoice.line_items.build(description: "Example assignment #{index + 1}", quantity: 1, rate: "100")
    end

    reader = pdf_reader
    assert_operator reader.page_count, :>, 1
    assert_printable_layout reader
    text = reader.pages.map(&:text).join(" ").gsub(/\s+/, " ")
    40.times { |index| assert_includes text, "Example assignment #{index + 1}" }
    assert_includes text, "$4000.00"
    assert_includes text, "Thank you."
  end

  private

  def pdf_reader
    PDF::Reader.new(StringIO.new(InvoiceDocument.new(@invoice).pdf))
  end

  def assert_printable_layout(reader)
    reader.pages.each do |page|
      assert_equal [ 0, 0, 612, 792 ], page.attributes.fetch(:MediaBox)
      # Disable crop filtering so off-page text cannot silently escape this check.
      runs = page.runs(rect: nil)
      assert_empty runs.reject { |run| run.x >= 53.9 && run.endx <= 558.1 && run.y >= 71.9 && run.endy <= 756.1 },
        "Text crossed a printable margin on page #{page.number}"

      paths = PagePaths.new
      page.walk(paths)
      next if paths.points.empty?

      assert_empty paths.points.reject { |point| point.x >= 53.9 && point.x <= 558.1 },
        "A table border or highlight crossed a printable margin on page #{page.number}"
      if runs.any? { |run| run.text == "Charge" }
        assert_in_delta 54, paths.points.map(&:x).min, 0.1
        assert_in_delta 558, paths.points.map(&:x).max, 0.1
      end
    end
  end

  class PagePaths < PDF::Reader::PageTextReceiver
    attr_reader :points

    def initialize = @points = []

    def begin_new_subpath(x, y) = @points << state.ctm_transform_point(x, y)
    def append_line(x, y) = @points << state.ctm_transform_point(x, y)
    def append_rectangle(x, y, width, height)
      begin_new_subpath(x, y)
      append_line(x + width, y + height)
    end
  end
end
