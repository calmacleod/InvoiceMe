require "test_helper"
require_relative "../test_helpers/invoice_numbering_google"

class InvoiceContactsSystemTest < ActionDispatch::SystemTestCase
  include InvoiceNumberingGoogle
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1100 ]

  test "add saved and manual contacts reorder remove autosave and preview names only" do
    users(:one).contacts.create!(name: "Fictional Avery", email: "avery@example.test", organization: "Example Club", address: "123 Fictional Lane")
    users(:one).contacts.create!(name: "Fictional Rowan", email: "rowan@example.test", organization: "Other Example Club", address: "456 Fictional Road")
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1", text: "Invoices"
    visit new_invoice_path
    fill_in "Identifying info", with: "EXAMPLE-CONTACTS"
    fill_in "description", with: "Example fees"
    fill_in "issued_on", with: Date.new(2031, 9, 15)
    fill_in "description-0", with: "Example services"
    fill_in "rate-0", with: "13.37"
    click_button "Add contacts"
    assert_selector "dialog[open]"
    assert_equal "Search saved contacts", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    find('input[aria-label="Search saved contacts"]').set("fictional avery")
    assert_text "1–1 of 1"
    find('button[aria-label="Use contact Fictional Avery"]').click
    find('input[aria-label="Search saved contacts"]').set("")
    assert_selector :field, "recipient", with: "Example Club"
    find('button[aria-label="Use contact Fictional Rowan"]').click
    click_button "Done"
    assert_selector :field, "recipient", with: "Example Club"
    assert_selector :field, "recipient_address", with: "123 Fictional Lane"
    click_button "Add contacts"
    assert_selector 'button[aria-label="Use contact Fictional Avery"]:disabled'
    click_button "Done"
    click_button "+ Add contact manually"
    fill_in "Contact 3 name", with: "Fictional Casey"
    find('button[aria-label="Move contact 3 up"]').click
    assert_selector :field, "Contact 2 name", with: "Fictional Casey"
    find('button[aria-label="Remove contact 1"]').click
    find('button[aria-label="Move contact 2 up"]').click
    click_button "Add contacts"
    find('button[aria-label="Use contact Fictional Avery"]').click
    click_button "Done"
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
    invoice = Invoice.find_by!(number: "2026_05_EXAMPLE-CONTACTS")
    assert_equal "rowan@example.test", invoice.contact_email
    visit edit_invoice_path(invoice)
    3.times { find('button[aria-label="Remove contact 1"]').click }
    click_button "Save & preview →"
    assert_selector ".doc-metadata", text: "ATTENTION: Example Club"
    assert_empty invoice.reload.contacts
  end

  test "create a contact on a draft and navigate without replacing the document" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_button "+ Create invoice"
    fill_in "description", with: "Synthetic meeting supplies"
    page.execute_script("window.invoiceMeDocumentMarker = true")

    click_button "Add contacts"
    find('input[aria-label="Search saved contacts"]').set("Fictional Lee")
    assert_text "No contacts found."
    click_button "New contact"
    within("dialog") do
      assert_field "Contact name", with: "Fictional Lee"
      fill_in "Organization", with: "Example Association"
      fill_in "Email", with: "lee@example.test"
      fill_in "Mailing address", with: "321 Fictional Crescent"
      click_button "Save & add to invoice"
    end

    assert_no_selector "dialog[open]"
    assert_field "description", with: "Synthetic meeting supplies"
    assert_field "recipient", with: "Example Association"
    assert_field "recipient_address", with: "321 Fictional Crescent"
    assert_field "Contact 1 email (optional)", with: "lee@example.test"
    assert_equal true, page.evaluate_script("window.invoiceMeDocumentMarker")
    click_link "Contacts"
    assert_selector "h1", text: "Contacts", exact_text: true
    assert_text "Fictional Lee"
    click_link "Draft workbench"
    click_link "Resume →"
    assert_field "Contact 1 name", with: "Fictional Lee"
    assert_equal true, page.evaluate_script("window.invoiceMeDocumentMarker")
  end
end
