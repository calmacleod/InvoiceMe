require "prawn"
require "prawn/table"

class OfficialPaymentStatement
  CONTACT = "Questions about this statement?".freeze
  FEE_NOTE = "* Association fee applies to game fees only. The rates are 8% on the first $2,500, 4% on the next $2,000, and 0% above $4,500.".freeze

  MARGIN = 42
  COLUMN_WIDTHS = [ 342, 138 ].freeze
  INK = "192323".freeze
  MUTED = "475356".freeze
  RULE = "C6CDD0".freeze
  SHADE = "F0F2F3".freeze

  def initialize(payment)
    @payment = payment
    @season = payment.season
  end

  def title = "#{@season.year} Earnings - #{@payment.official_name}"
  def filename = "#{@season.year}-earnings-#{@payment.official_name.parameterize}"
  def organization = @season.issuer.fetch("name")
  def heading = "#{@season.year} Earnings Statement"
  def official_name = @payment.official_name
  def payment_details
    payment_number = "Payment Number: #{@payment.payment_number}" if @payment.payment_number
    [ payment_number, "Cheque Number: #{@payment.cheque_number || '—'}" ].compact.join("   |   ")
  end
  def email = @season.issuer.fetch("email")
  def visible_note = @payment.visible_note
  def fee_note? = @payment.association_fee_cents.positive?

  def rows
    earnings = [
      [ "Game Fees", @payment.game_fees_cents ],
      [ "Travel/OT", @payment.travel_ot_cents ],
      [ "Evaluations", @payment.evaluations_cents ],
      [ "Prepayment Refund", @payment.prepayment_refund_cents ]
    ]
    deductions = [
      [ "Association Fee*", @payment.association_fee_cents ],
      [ "OFOA Registration", @payment.registration_cents ],
      [ "Banquet", @payment.banquet_cents ],
      [ "#{@season.year + 1} Prepayment", @payment.next_year_prepayment_cents ]
    ]
    other = [
      [ "Other", @payment.other_cents ],
      *@payment.adjustments.map { |item| item.values_at("label", "amount_cents") }
    ]
    details = [ [ "Earnings", earnings ], [ "Deductions", deductions ], [ "Other & Adjustments", other ] ].flat_map do |label, items|
      entries = items.filter_map { |description, cents| [ :item, description, amount(cents) ] unless cents.zero? }
      entries.empty? ? [] : [ [ :section, label ], *entries ]
    end
    header = details.empty? ? [] : [ [ :columns, "Item", "Amount (CAD)" ] ]
    [ *header, *details, [ :total, "Net Earnings", amount(@payment.net_cents) ] ]
  end

  def odt
    OdtDocument.package(content, styles: styles)
  end

  def export_to_google!
    @payment.with_lock do
      raise GoogleApi::Error, "Review and save earnings before exporting." unless @payment.reviewed_at

      digest = Digest::SHA256.new.update(content).update(styles).update(OdtDocument::LOGO.binread).hexdigest
      if @payment.google_doc_id && @payment.google_doc_digest == digest
        next @payment.google_doc_id
      end

      google = GoogleApi.new
      root = google.request(:get, "https://www.googleapis.com/drive/v3/files/root?fields=id", operation: "finding the treasurer’s My Drive").fetch("id")
      doc_id = google.upload(name: title, folder: root, mime: OdtDocument::MIME, bytes: odt,
        key: "official-payment-#{@payment.id}", target_mime: "application/vnd.google-apps.document", file_id: @payment.google_doc_id, replace: true)
      @payment.update!(google_doc_id: doc_id, google_doc_digest: digest)
      doc_id
    end
  end

  def pdf
    Prawn::Document.new(page_size: "LETTER", margin: MARGIN) do |pdf|
      font_dir = Rails.root.join("app/assets/fonts")
      pdf.font_families.update("Statement" => { normal: font_dir.join("regular.ttf").to_s, bold: font_dir.join("bold.ttf").to_s })
      pdf.font "Statement"
      pdf.fill_color INK
      pdf.image OdtDocument::LOGO.to_s, at: [ 0, pdf.bounds.top ], width: 42
      pdf.bounding_box([ 52, pdf.bounds.top - 12 ], width: pdf.bounds.width - 52) do
        pdf.text organization, size: 15, style: :bold
      end
      pdf.move_cursor_to([ pdf.cursor - 11, pdf.bounds.top - 51 ].min)
      pdf.text heading, size: 23, style: :bold
      pdf.move_down 3
      pdf.text official_name, size: 15, style: :bold
      pdf.move_down 5
      pdf.text payment_details, size: 10, color: MUTED
      pdf.move_down 14

      pdf.table(rows.map { |kind, label, value| pdf_row(kind, label, value) },
        column_widths: COLUMN_WIDTHS, cell_style: { valign: :center, border_width: 0.45, border_color: RULE, padding: [ 1, 8, 5, 8 ] })

      if visible_note
        pdf.move_down 11
        pdf.text "Payment note", size: 10.5, style: :bold
        pdf.move_down 3
        pdf.text visible_note, size: 10.5, leading: 2
      end

      pdf.move_down 11
      if fee_note?
        pdf.text FEE_NOTE, size: 9, color: MUTED
        pdf.move_down 5
      end
      pdf.formatted_text [ { text: "#{CONTACT} " }, { text: email, link: "mailto:#{email}", styles: [ :underline ] } ], size: 9
    end.render
  end

  private

  def amount(cents)
    dollars, remainder = cents.abs.divmod(100)
    formatted = ActiveSupport::NumberHelper.number_to_delimited(dollars)
    format("%s$%s.%02d", cents.negative? ? "-" : "", formatted, remainder)
  end

  def pdf_row(kind, label, value)
    style = { size: 10.5, font_style: :bold, background_color: SHADE }
    case kind
    when :section
      [ style.merge(content: label, colspan: 2) ]
    when :columns
      [ style.merge(content: label), style.merge(content: value, align: :right) ]
    when :total
      total_style = style.merge(padding: [ 3, 8, 7, 8 ])
      [ total_style.merge(content: label), total_style.merge(content: value, align: :right, size: 15) ]
    else
      [ { content: label, size: 10.5 }, { content: value, size: 10.5, align: :right } ]
    end
  end

  def content
    ApplicationController.render(template: "official_payments/statement", formats: [ :xml ], layout: false, assigns: { statement: self })
  end

  def styles
    Rails.root.join("app/templates/official_payment_styles.xml").read
  end
end
