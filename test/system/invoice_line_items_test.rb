require "test_helper"

class InvoiceLineItemsSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1100 ]

  test "reorder mixed pricing lines and retain amounts and order through autosave and preview" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1", text: "Invoices."
    visit new_invoice_path
    fill_in "number", with: "EXAMPLE-LINE-ITEMS"
    fill_in "recipient", with: "Example Club"
    fill_in "description", with: "Example fees"
    fill_in "issued_on", with: Date.new(2031, 9, 15)
    fill_in "description-0", with: "Example services"
    fill_in "quantity-0", with: "2"
    fill_in "rate-0", with: "13.37"
    click_button "+ Add amount-only item"
    fill_in "description-1", with: "Example travel"
    fill_in "rate-1", with: "24.75"
    within('[role="group"][aria-label="Line item 2"]') do
      assert_no_selector 'input[id^="quantity-"]'
      assert_selector :field, "Amount (CAD)", with: "24.75"
    end
    click_button "+ Add line item", exact: true
    fill_in "description-2", with: "Example parking"
    fill_in "rate-2", with: "5.00"
    find('button[aria-label="Move line item 2 down"]').click
    assert_selector :field, "description-2", with: "Example travel"
    find('button[aria-label="Move line item 3 up"]').click
    assert_selector :field, "description-1", with: "Example travel"
    find('button[aria-label="Move line item 2 down"]').click
    select "Amount only", from: "pricing-0"
    assert_no_selector "#quantity-0"
    assert_selector :field, "rate-0", with: "26.74"
    select "Quantity × rate", from: "pricing-0"
    assert_selector :field, "quantity-0", with: "1"
    assert_text "$56.49"
    assert_text "All changes saved"
    draft_path = page.current_path
    visit games_path
    visit draft_path
    assert_selector :field, "description-2", with: "Example travel"
    assert_selector :select, "pricing-2", selected: "Amount only"
    click_button "Save & preview →"
    assert_selector ".doc-items tbody tr:nth-child(1)", text: "Example services"
    assert_selector ".doc-items tbody tr:nth-child(2)", text: "Example parking"
    assert_equal [ "3", "Example travel", "", "", "$24.75" ], all(".doc-items tbody tr:nth-child(3) td").map(&:text)
    invoice = Invoice.find_by!(number: "EXAMPLE-LINE-ITEMS")
    visit edit_invoice_path(invoice)
    find('button[aria-label="Move line item 3 up"]').click
    find('button[aria-label="Remove line item 3"]').click
    click_button "Save & preview →"
    assert_selector ".doc-items tbody tr:nth-child(2)", text: "Example travel"
    assert_equal [ "Example services", "Example travel" ], invoice.reload.line_items.pluck(:description)
    assert_equal 5149, invoice.total_cents
    assert_equal [ "2", "Example travel", "", "", "$24.75" ], all(".doc-items tbody tr:nth-child(2) td").map(&:text)
  end
end
