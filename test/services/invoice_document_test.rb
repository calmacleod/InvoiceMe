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

  test "HTML PDF and Google document include every contact name and no contact emails" do
    @invoice.contacts = [ { name: "Fictional Avery & Coordinator", email: "avery@example.test" }, { name: "Fictional Rowan", email: "rowan@example.test" } ]
    document = InvoiceDocument.new(@invoice)
    texts = [ Nokogiri::HTML(document.html).text, pdf_reader.pages.map(&:text).join(" ") ]
    Zip::File.open_buffer(document.odt) do |zip|
      texts << Nokogiri::XML(zip.read("content.xml")) { |config| config.strict }.text
    end
    texts.each do |text|
      assert_includes text.gsub(/\s+/, " "), "ATTENTION: Fictional Avery & Coordinator, Fictional Rowan"
      assert_not_includes text, "avery@example.test"
      assert_not_includes text, "rowan@example.test"
    end
    assert_printable_layout pdf_reader
  end

  test "legacy combined contact emails are excluded from all invoice documents" do
    @invoice.contact = "Fictional Avery <avery@example.test>"
    document = InvoiceDocument.new(@invoice)
    texts = [ Nokogiri::HTML(document.html).text, pdf_reader.pages.map(&:text).join(" ") ]
    Zip::File.open_buffer(document.odt) { |zip| texts << zip.read("content.xml") }
    texts.each do |text|
      assert_includes text, "ATTENTION: Fictional Avery"
      assert_not_includes text, "avery@example.test"
    end
  end

  test "amount-only rows omit quantity and rate in HTML PDF and Google document content" do
    @invoice.line_items.last.amount_only = true
    html = Nokogiri::HTML(InvoiceDocument.new(@invoice).html)
    row = html.css(".doc-items tbody tr").find { |item| item.at_css("td:nth-child(2)")&.text == "Travel" }
    assert_equal [ "3", "Travel", "", "", "$20.00" ], row.css("td").map(&:text)
    Zip::File.open_buffer(InvoiceDocument.new(@invoice).odt) do |zip|
      xml = Nokogiri::XML(zip.read("content.xml")) { |config| config.strict }
      row = xml.xpath("//table:table-row", xml.root.namespaces).find { |item| item.text.include?("Travel") }
      assert_equal [ "3", "Travel", "", "", "$20.00" ], row.xpath("table:table-cell", xml.root.namespaces).map(&:text)
    end
    reader = pdf_reader
    assert_printable_layout reader
    runs = reader.pages.first.runs
    travel = runs.find { |run| run.text == "Travel" }
    row = runs.select { |run| (run.y - travel.y).abs < 1 }.sort_by(&:x)
    assert_equal [ "3", "Travel", "$20.00" ], row.map(&:text)
    assert_includes reader.pages.first.text, "$1870.00"
  end

  test "ODT uses the required mimetype header and ordinary ZIP entries" do
    bytes = InvoiceDocument.new(@invoice).odt
    assert_equal "PK\x03\x04".b, bytes.byteslice(0, 4)
    assert_equal 0, bytes.byteslice(8, 2).unpack1("v"), "The mimetype entry must be uncompressed"
    assert_equal 8, bytes.byteslice(26, 2).unpack1("v")
    assert_equal 0, bytes.byteslice(28, 2).unpack1("v"), "ODF prohibits extra fields in the mimetype header"
    assert_equal "mimetype", bytes.byteslice(30, 8)
    assert_equal "application/vnd.oasis.opendocument.text", bytes.byteslice(38, 39)

    Zip::File.open_buffer(bytes) do |zip|
      assert_equal "mimetype", zip.entries.first.name
      zip.entries.each do |entry|
        assert_not entry.zip64?, "Small ODT entries must not require ZIP64: #{entry.name}"
        assert_operator bytes.byteslice(entry.local_header_offset + 4, 2).unpack1("v"), :<=, 20
        assert_equal entry.size, zip.read(entry.name).bytesize
      end
      manifest = Nokogiri::XML(zip.read("META-INF/manifest.xml")) { |config| config.strict }
      assert_equal "application/vnd.oasis.opendocument.text", manifest.at_xpath("//manifest:file-entry[@manifest:full-path='/']", "manifest" => "urn:oasis:names:tc:opendocument:xmlns:manifest:1.0")["manifest:media-type"]
    end
  end

  test "ODT hyperlinks and page orientation conform to OpenDocument attributes" do
    Zip::File.open_buffer(InvoiceDocument.new(@invoice).odt) do |zip|
      content = Nokogiri::XML(zip.read("content.xml")) { |config| config.strict }
      links = content.xpath("//text:a", content.root.namespaces)
      assert_equal 2, links.size
      links.each do |link|
        assert_equal "simple", link["xlink:type"]
        assert_equal "mailto:treasurer@example.test", link["xlink:href"]
      end
      styles = Nokogiri::XML(zip.read("styles.xml")) { |config| config.strict }
      layout = styles.at_xpath("//style:page-layout-properties", styles.root.namespaces)
      assert_equal "portrait", layout["style:print-orientation"]
      assert_nil layout["fo:print-orientation"]
    end
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
