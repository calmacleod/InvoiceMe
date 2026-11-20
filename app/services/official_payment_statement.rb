require "prawn"
require "prawn/table"

class OfficialPaymentStatement
  CONTACT = "If you have any questions or concerns regarding the amounts listed please contact".freeze
  FEE_NOTE = "* Association fee is calculated using the following formula:".freeze
  FEE_TIERS = [
    "8% on any amount up to $2500.00",
    "4% on the portion above $2500.00 up to $4500.00",
    "0% above $4500.00"
  ].freeze

  def initialize(payment)
    @payment = payment
    @season = payment.season
  end

  def title = "#{@season.year} Earnings - #{@payment.official_name}"
  def filename = "#{@season.year}-earnings-#{@payment.official_name.parameterize}"
  def organization = @season.issuer.fetch("name").upcase
  def heading = "#{@season.year} EARNINGS FOR #{@payment.official_name}"
  def cheque = "Cheque Number: #{@payment.cheque_number || '—'}"
  def email = @season.issuer.fetch("email")

  def rows
    [
      [ "Earnings" ],
      [ "Game Fees", @payment.game_fees_cents ],
      [ "Travel/OT", @payment.travel_ot_cents ],
      [ "Evaluations", @payment.evaluations_cents ],
      [ "Prepayment Refund", @payment.prepayment_refund_cents ],
      [ "Deductions" ],
      [ "Association Fee*", @payment.association_fee_cents ],
      [ "OFOA Registration", @payment.registration_cents ],
      [ "Banquet", @payment.banquet_cents ],
      [ "#{@season.year + 1} Prepayment", @payment.next_year_prepayment_cents ],
      [ "Misc" ],
      [ "Other", @payment.other_cents ],
      [ "Total" ],
      [ "Net Earnings", @payment.net_cents ]
    ]
  end

  def amount(cents)
    format("%s$%d.%02d", cents.negative? ? "-" : "", *cents.abs.divmod(100))
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
    Prawn::Document.new(page_size: "LETTER", margin: 72) do |pdf|
      font_dir = Rails.root.join("app/assets/fonts")
      pdf.font_families.update("Statement" => { normal: font_dir.join("regular.ttf").to_s, bold: font_dir.join("bold.ttf").to_s })
      pdf.font "Statement", size: 11
      pdf.image OdtDocument::LOGO.to_s, at: [ -10, pdf.bounds.top ], width: 72, height: 70
      pdf.text_box organization, at: [ 71, pdf.bounds.top - 10 ], width: 407, height: 38, valign: :center, size: 15, style: :bold, overflow: :shrink_to_fit
      pdf.move_down 93
      pdf.text heading, style: :bold
      pdf.text cheque, style: :bold
      pdf.move_cursor_to([ pdf.cursor - 14, pdf.bounds.top - 137 ].min)
      table_rows = rows.map do |label, cents|
        if cents.nil?
          [ { content: label, colspan: 2, align: :center, font_style: :bold, background_color: "D7D7D7" } ]
        else
          [
            { content: label, font_style: :bold, background_color: "D7D7D7" },
            { content: amount(cents), align: :right, font: "Courier" }
          ]
        end
      end
      pdf.table(table_rows, column_widths: [ 191, 172 ], cell_style: { height: 24, padding: [ 0, 5 ], valign: :center, border_width: 0.75 })
      pdf.move_down 30
      pdf.text CONTACT, align: :center
      pdf.formatted_text [ { text: email, link: "mailto:#{email}", color: "0563C1", styles: [ :underline, :bold ] } ], align: :center
      pdf.move_down 32
      pdf.text FEE_NOTE
      pdf.indent(36) do
        FEE_TIERS.each { |tier| pdf.text tier }
        pdf.formatted_text [ { text: "It is " }, { text: "only", styles: [ :bold ] }, { text: " deducted from game fees" } ]
      end
    end.render
  end

  private

  def content
    ApplicationController.render(template: "official_payments/statement", formats: [ :xml ], layout: false, assigns: { statement: self })
  end

  def styles
    Rails.root.join("app/templates/official_payment_styles.xml").read
  end
end
