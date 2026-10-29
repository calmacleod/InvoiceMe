require "test_helper"

class InvoiceTotalsTest < ActiveSupport::TestCase
  test "aggregates match exact per-line rounding with multiple payments and exclude drafts and other years" do
    season = seasons(:current)
    amounts = [ [ "0.005", 100 ], [ "0.004", 100 ], [ "2.5", 1337 ], [ "999999.999", 99999999 ], [ "1", 0 ] ]
    invoices = amounts.each_with_index.map do |(quantity, rate), index|
      invoice = season.invoices.create!(number: "EXAMPLE-#{index}", recipient: "Example Club", description: "Fictional", issued_on: Date.current,
        line_items_attributes: [ { description: "Example A", quantity: quantity, rate_cents: rate }, { description: "Example B", quantity: "0.005", rate_cents: 100 } ])
      invoice.finalize!
      invoice
    end
    invoices[2].payments.create!(amount_cents: 1, received_on: Date.current, method: "Example")
    invoices[2].payments.create!(amount_cents: 2, received_on: Date.current, method: "Example")
    invoices[0].payments.create!(amount_cents: invoices[0].total_cents, received_on: Date.current, method: "Example")
    season.invoices.create!(number: "EXAMPLE-DRAFT", recipient: "Example", description: "Draft", issued_on: Date.current, line_items_attributes: [ { description: "Excluded", quantity: 1, rate_cents: 9999 } ])
    other = Season.create!(year: 2035, sheet_name: "Example", issuer: season.issuer)
    other.invoices.create!(number: "EXAMPLE-OTHER", recipient: "Example", description: "Other", issued_on: Date.current, line_items_attributes: [ { description: "Excluded", quantity: 1, rate_cents: 9999 } ]).finalize!
    expected = { invoiced: invoices.sum(&:total_cents), received: invoices.sum(&:received_cents), owed: invoices.sum(&:owed_cents), outstanding: invoices.count { |invoice| invoice.owed_cents.positive? }, drafts: 1 }
    assert_equal expected, InvoiceTotals.new(season.invoices).call
  end
end
