module ApplicationHelper
  def money(cents) = number_to_currency(cents.to_i / 100.0)
  def invoice_money(cents, rate: false)
    number_to_currency(BigDecimal(cents.to_s) / 100, delimiter: "", precision: rate && cents % 100 == 0 ? 0 : 2)
  end
  def invoice_heading(invoice)
    invoice.recipient.include?(invoice.season.year.to_s) ? invoice.recipient : "#{invoice.recipient} #{invoice.season.year}"
  end
  def invoice_payment_instructions(text)
    safe_join(text.to_s.split(/(check|cheque|e-transfer)/i).map { |part| part.match?(/\A(check|cheque|e-transfer)\z/i) ? tag.strong(tag.em(tag.u(part))) : part })
  end
  def badge(status)
    tag.span(status, class: "badge #{status.downcase.tr(' ', '-')}")
  end
end
