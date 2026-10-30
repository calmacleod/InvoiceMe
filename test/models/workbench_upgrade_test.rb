require "test_helper"
require Rails.root.join("db/migrate/20261030133000_add_existing_invoice_workbenches")

class WorkbenchUpgradeTest < ActiveSupport::TestCase
  def make_invoice(number)
    seasons(:current).invoices.create!(number: number, recipient: "Fictional Club", description: "Example", issued_on: Date.current,
      line_items_attributes: [ { description: "Example", quantity: 1, rate_cents: 1337 } ])
  end

  test "sole account receives existing drafts once without altering invoices or assigning finalized records" do
    users(:two).destroy!
    assert_equal 1, User.count
    invoice = make_invoice("EXAMPLE-LEGACY")
    finalized = make_invoice("EXAMPLE-FINALIZED")
    finalized.finalize!
    attributes = invoice.attributes
    migration = AddExistingInvoiceWorkbenches.new
    assert_difference "InvoiceDraft.count", 1 do
      migration.suppress_messages { migration.up }
      migration.suppress_messages { migration.up }
    end
    draft = InvoiceDraft.find_by!(invoice: invoice)
    assert_equal users(:one), draft.user
    assert_empty draft.data
    assert_equal "EXAMPLE-LEGACY · Fictional Club", draft.title
    assert_equal attributes, invoice.reload.attributes
    assert_equal 1337, invoice.total_cents
    assert_nil InvoiceDraft.find_by(invoice: finalized)
  end

  test "multiple accounts require an explicit choice of workbench owner" do
    make_invoice("EXAMPLE-MULTI")
    assert_equal 2, User.count
    assert_no_difference "InvoiceDraft.count" do
      migration = AddExistingInvoiceWorkbenches.new
      migration.suppress_messages { migration.up }
    end
  end
end
