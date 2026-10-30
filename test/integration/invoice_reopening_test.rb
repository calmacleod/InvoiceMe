require "test_helper"

class InvoiceReopeningTest < ActionDispatch::IntegrationTest
  setup do
    @invoice = seasons(:current).invoices.create!(number: "2031_Example", recipient: "Example Club", description: "Fictional services", issued_on: Date.new(2031, 9, 15),
      line_items_attributes: [ { description: "Fictional services", quantity: 1, rate: "13.37" } ])
    @invoice.finalize!
  end

  test "reopening requires authentication" do
    post reopen_invoice_path(@invoice)
    assert_redirected_to new_session_path
    assert @invoice.reload.finalized_at
  end

  test "return to draft resumes the editor and retains the invoice after editing" do
    sign_in_as(users(:one))
    post reopen_invoice_path(@invoice)
    assert_redirected_to edit_invoice_path(@invoice)
    follow_redirect!
    assert_inertia_component "invoices/Edit"
    assert inertia.props[:invoice][:reopened]
    patch invoice_path(@invoice), params: { invoice: { recipient: "Changed fictional club" } }
    assert_equal "Changed fictional club", @invoice.reload.recipient
    assert_no_difference "Invoice.count" do
      delete invoice_path(@invoice)
    end
    assert_redirected_to invoice_path(@invoice)
    assert_no_difference "Invoice.count" do
      post reopen_invoice_path(@invoice)
    end
    assert_redirected_to edit_invoice_path(@invoice)
  end

  test "blocked reopening explains the reason and leaves the invoice finalized" do
    sign_in_as(users(:one))
    export = @invoice.invoice_exports.create!
    post reopen_invoice_path(@invoice)
    assert_redirected_to invoice_path(@invoice)
    assert_includes flash[:alert], "Wait for the Google export"
    assert @invoice.reload.finalized_at
    export.fail!("Fictional failure")
    @invoice.payments.create!(amount_cents: 100, received_on: Date.new(2031, 9, 16), method: "Cheque")
    post reopen_invoice_path(@invoice)
    assert_redirected_to invoice_path(@invoice)
    assert_includes flash[:alert], "recorded payments"
    assert @invoice.reload.finalized_at
  end
end
