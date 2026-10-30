require "test_helper"

class InvoiceContactsSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1100 ]

  test "add saved and manual contacts reorder remove autosave and preview names only" do
    users(:one).contacts.create!(name: "Fictional Avery", email: "avery@example.test", organization: "Example Club", address: "123 Fictional Lane")
    users(:one).contacts.create!(name: "Fictional Rowan", email: "rowan@example.test", organization: "Other Example Club", address: "456 Fictional Road")
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1", text: "Invoices."
    visit new_invoice_path
    fill_in "number", with: "EXAMPLE-CONTACTS"
    fill_in "description", with: "Example fees"
    fill_in "issued_on", with: Date.new(2031, 9, 15)
    fill_in "description-0", with: "Example services"
    fill_in "rate-0", with: "13.37"
    click_button "Add saved contacts"
    find('button[aria-label="Use contact Fictional Avery"]').click
    assert_selector :field, "recipient", with: "Example Club"
    find('button[aria-label="Use contact Fictional Rowan"]').click
    assert_selector :field, "recipient", with: "Example Club"
    assert_selector :field, "recipient_address", with: "123 Fictional Lane"
    assert_selector 'button[aria-label="Use contact Fictional Avery"]:disabled'
    click_button "+ Add contact manually"
    fill_in "Contact 3 name", with: "Fictional Casey"
    find('button[aria-label="Move contact 3 up"]').click
    assert_selector :field, "Contact 2 name", with: "Fictional Casey"
    find('button[aria-label="Remove contact 1"]').click
    find('button[aria-label="Move contact 2 up"]').click
    find('button[aria-label="Use contact Fictional Avery"]').click
    click_button "Close saved contacts"
    assert_text "All changes saved"
    draft_path = page.current_path
    visit games_path
    visit draft_path
    assert_selector :field, "Contact 1 name", with: "Fictional Rowan"
    assert_selector :field, "Contact 1 email (optional)", with: "rowan@example.test"
    assert_selector :field, "Contact 2 name", with: "Fictional Casey"
    assert_selector :field, "Contact 3 name", with: "Fictional Avery"
    click_button "Save & preview →"
    within ".document" do
      assert_text "ATTENTION: Fictional Rowan, Fictional Casey, Fictional Avery"
      assert_no_text "rowan@example.test"
      assert_no_text "avery@example.test"
    end
    invoice = Invoice.find_by!(number: "EXAMPLE-CONTACTS")
    assert_equal "rowan@example.test", invoice.contact_email
    visit edit_invoice_path(invoice)
    3.times { find('button[aria-label="Remove contact 1"]').click }
    click_button "Save & preview →"
    assert_selector ".doc-metadata", text: "ATTENTION: Example Club"
    assert_empty invoice.reload.contacts
  end
end
