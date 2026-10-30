require "prawn"
require "prawn/table"
require "zip"
class InvoiceDocument
  def initialize(invoice) = @invoice = invoice
  def html
    ApplicationController.render(template: "invoices/document", layout: "document", assigns: { invoice: @invoice })
  end
  def odt
    content = ApplicationController.render(template: "invoices/odt", formats: [ :xml ], layout: false, assigns: { invoice: @invoice })
    manifest = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">
        <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/>
        <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
        <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
        <manifest:file-entry manifest:full-path="Pictures/logo.jpg" manifest:media-type="image/jpeg"/>
      </manifest:manifest>
    XML
    files = {
      "mimetype" => "application/vnd.oasis.opendocument.text",
      "content.xml" => content,
      "styles.xml" => Rails.root.join("app/templates/invoice_styles.xml").read,
      "Pictures/logo.jpg" => Rails.root.join("app/assets/images/eotfoa-logo.jpg").binread,
      "META-INF/manifest.xml" => manifest
    }
    Zip::OutputStream.write_buffer(suppress_extra_fields: true) do |zip|
      files.each do |name, bytes|
        entry = Zip::Entry.new("", name)
        # ODF requires mimetype first, uncompressed, with no ZIP extra fields.
        # Supplying sizes also avoids Rubyzip's ZIP64 placeholders in small files.
        entry.size = bytes.bytesize
        entry.compression_method = name == "mimetype" ? Zip::Entry::STORED : Zip::Entry::DEFLATED
        zip.put_next_entry(entry)
        zip.write bytes
      end
    end.string
  end
  def pdf
    i = @invoice
    Prawn::Document.new(page_size: "LETTER", margin: [ 36, 54, 72, 54 ]) do |pdf|
      font_dir = Rails.root.join("app/assets/fonts")
      pdf.font_families.update("InvoiceCalibri" => { normal: font_dir.join("regular.ttf").to_s, bold: font_dir.join("bold.ttf").to_s, italic: font_dir.join("italic.ttf").to_s, bold_italic: font_dir.join("bold_italic.ttf").to_s })
      pdf.font "InvoiceCalibri", size: 12
      pdf.fill_color "000000"
      top = pdf.bounds.top
      pdf.image Rails.root.join("app/assets/images/eotfoa-logo.jpg").to_s, at: [ -10.5, top ], width: 72.06, height: 70.1
      pdf.bounding_box([ 86.55, top - 17 ], width: pdf.bounds.width - 86.55) do
        pdf.text i.issuer.fetch("name").upcase, size: 15, style: :bold
      end
      pdf.move_cursor_to([ top - 81, pdf.cursor - 11 ].min)
      pdf.formatted_text [ { text: "FINAL INVOICE FOR ", size: 14 }, { text: heading, size: 14, styles: [ :bold ] } ]
      pdf.move_down 14
      pdf.text "Invoice date: #{i.issued_on.strftime('%B %-d, %Y')}"
      pdf.text "Invoice number: #{i.number}"
      pdf.text "Due date: #{i.due_on.strftime('%B %-d, %Y')}" if i.due_on
      pdf.text i.recipient_address if i.recipient_address.present?
      pdf.text "ATTENTION: #{i.contact.presence || i.recipient}", style: :bold
      pdf.move_down 16
      rows = [ [ "Item", "Description", "Quantity", "Rate", "Charge" ] ]
      i.line_items.each_with_index { |l, n| rows << [ (n+1).to_s, l.description, quantity(l.quantity), money(l.rate_cents, rate: true), money(l.total_cents) ] }
      [ 5 - i.line_items.size, 0 ].max.times { rows << [ "", "", "", "", "" ] }
      rows << [ { content: "Total", colspan: 4, font_style: :bold }, money(i.total_cents) ]
      # Keep the preview's column proportions inside the PDF's printable area.
      column_widths = [ 6.46, 57.77, 10.59, 11.83, 13.35 ].map { |percent| pdf.bounds.width * percent / 100 }
      pdf.table(rows, width: pdf.bounds.width, column_widths: column_widths, header: true, cell_style: { size: 10, padding: [ 0, 5 ], borders: [ :top, :bottom, :left, :right ], border_width: 1, border_color: "000000", align: :center, valign: :top }) do |t|
        (1..rows.size-2).each do |index|
          t.row(index).padding_top = 1
          t.row(index).height = [ 20, t.row(index).map(&:height).max ].max
        end
        t.row(0).background_color = "CCCCCC"
        t.row(0).font_style = :bold
        t.row(0).height = 16
        t.row(-1).height = 16
      end
      pdf.start_new_page if pdf.cursor < 80
      pdf.move_down 15
      total_width = pdf.bounds.width * 0.7446
      label_width = total_width * 0.7
      pdf.fill_color "FFFF00"
      pdf.fill_rectangle [ 0, pdf.cursor ], total_width, 14.65
      pdf.fill_color "FF0000"
      pdf.text_box "TOTAL PAYABLE", at: [ 0, pdf.cursor ], width: label_width, height: 15, size: 12, style: :bold
      pdf.text_box money(i.total_cents), at: [ label_width, pdf.cursor ], width: total_width - label_width, height: 15, size: 12, style: :bold, align: :right
      pdf.move_down 29.3
      pdf.fill_color "000000"
      pdf.formatted_text instruction_fragments(i.issuer["payment_instructions"].to_s)
      pdf.move_down 14.65
      pdf.formatted_text [ { text: "If paying by " }, { text: "e-transfer", styles: [ :bold ] }, { text: ", please email " }, email_fragment ]
      pdf.move_down 14.65
      pdf.formatted_text [ { text: "If paying by " }, { text: "check", styles: [ :bold ] }, { text: ", please make it payable to:" } ]
      pdf.text i.issuer["payable_to"].to_s, style: :bold
      pdf.text "And mail to"
      pdf.text "#{i.issuer['treasurer']}\n#{i.issuer['address']}", style: :bold
      if i.public_notes.present?
        pdf.move_down 14.65
        pdf.text i.public_notes
      end
      signature = "#{i.issuer['treasurer']}\nTreasurer, EOTFOA"
      signoff_height = 29.3 + pdf.height_of("Thank you.") + pdf.height_of(signature) + pdf.height_of_formatted([ email_fragment ])
      pdf.start_new_page if pdf.cursor < signoff_height
      pdf.move_down 14.65
      pdf.text "Thank you."
      pdf.move_down 14.65
      pdf.text signature
      pdf.formatted_text [ email_fragment ]
    end.render
  end
  private
  def heading = ApplicationController.helpers.invoice_heading(@invoice)
  def quantity(value) = ApplicationController.helpers.number_with_precision(value, precision: 3, strip_insignificant_zeros: true)
  def money(cents, rate: false) = ApplicationController.helpers.invoice_money(cents, rate: rate)
  def email_fragment = { text: @invoice.issuer["email"].to_s, color: "0563C1", styles: [ :underline ], link: "mailto:#{@invoice.issuer['email']}" }
  def instruction_fragments(text)
    text.split(/(check|cheque|e-transfer)/i).map { |part| { text: part, styles: part.match?(/\A(check|cheque|e-transfer)\z/i) ? [ :bold, :italic, :underline ] : [] } }
  end
end
