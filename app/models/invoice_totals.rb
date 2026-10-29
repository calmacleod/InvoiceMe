class InvoiceTotals
  def initialize(invoices)
    @invoices = invoices
  end

  def call
    finalized = @invoices.where.not(finalized_at: nil).select(:id)
    # Quantities have at most three decimal places and rates are integer cents.
    # SQLite integer arithmetic rounds EACH nonnegative line half up, exactly as
    # LineItem#total_cents does, without loading every line or multiplying joins.
    line_cents = "SUM((CAST(ROUND(quantity * 1000) AS INTEGER) * rate_cents + 500) / 1000)"
    totals = LineItem.where(invoice_id: finalized).group(:invoice_id).pluck(:invoice_id, Arel.sql(line_cents)).to_h
    payments = Payment.where(invoice_id: finalized).group(:invoice_id).sum(:amount_cents)
    invoiced = totals.values.sum
    received = payments.values.sum
    { invoiced: invoiced, received: received, owed: invoiced - received,
      outstanding: totals.count { |id, total| total > payments.fetch(id, 0) }, drafts: @invoices.where(finalized_at: nil).count }
  end
end
