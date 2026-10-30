require "test_helper"

class ContactsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    post select_year_path, params: { id: @season.id }
  end

  test "create edit search and delete contacts without changing copied invoice details" do
    post contacts_path, params: { contact: { name: " Fictional Rowan ", organization: " Example_% Club ", email: " ROWAN@EXAMPLE.TEST ", phone: "+1 555 0100", address: "123 Fictional Street\nExample City", notes: "Private fictional contact note" } }
    assert_redirected_to contacts_path
    contact = users(:one).contacts.last
    assert_equal "rowan@example.test", contact.email
    assert_equal "Fictional Rowan", contact.name
    get contacts_path, params: { q: "_%" }
    assert_equal [ contact.id ], inertia.props[:contacts].map { |item| item["id"] }
    refute_includes response.body, "Private fictional contact note"
    copied = contact.recipient_props
    invoice = @season.invoices.create!(number: "EXAMPLE-CONTACT", recipient: copied[:recipient], contacts: [ copied.slice("name", "email") ], recipient_address: copied["address"], description: "Example", issued_on: "2031-02-17", line_items_attributes: [ { description: "Example", quantity: 1, rate_cents: 1337 } ])
    snapshot = invoice.attributes.slice("recipient", "contacts", "recipient_address")
    draft = InvoiceDraft.create!(user: users(:one), season: @season, client_key: "example-contact-snapshot", data: snapshot)
    patch contact_path(contact), params: { contact: { name: "Changed fictional name", email: "changed@example.test", organization: "Changed fictional organization", address: "Changed address" } }
    assert_redirected_to contacts_path
    delete contact_path(contact)
    assert_redirected_to contacts_path
    assert_equal snapshot, invoice.reload.attributes.slice("recipient", "contacts", "recipient_address")
    assert_equal snapshot, draft.reload.data
  end

  test "contact picker is optional searchable private and available across years" do
    contact = users(:one).contacts.create!(name: "Fictional Avery", organization: "Example Club", email: "avery@example.test", address: "123 Fictional Lane", notes: "PRIVATE CONTACT NOTE")
    users(:two).contacts.create!(name: "Private other contact", email: "other@example.test")
    get new_invoice_path, headers: inertia_headers
    refute response.parsed_body["props"].key?("contact_options")
    other = Season.create!(year: 2033, sheet_name: "Example", issuer: @season.issuer)
    post select_year_path, params: { id: other.id }
    get new_invoice_path, params: { contact_q: "avery" }, headers: inertia_headers.merge("X-Inertia-Partial-Component" => "invoices/Edit", "X-Inertia-Partial-Data" => "contact_options")
    recipient = response.parsed_body.dig("props", "contact_options", "contacts", 0)
    assert_equal contact.id, recipient["id"]
    assert_equal "Example Club", recipient["recipient"]
    assert_equal "Fictional Avery", recipient["name"]
    assert_equal "avery@example.test", recipient["email"]
    refute recipient.key?("contact")
    assert_equal "123 Fictional Lane", recipient["address"]
    refute_includes response.body, "PRIVATE CONTACT NOTE"
    refute_includes response.body, "Private other contact"
    refute response.parsed_body["props"].key?("invoice")
  end

  test "authentication ownership and validation apply to contact management" do
    contact = users(:two).contacts.create!(name: "Other fictional owner")
    get edit_contact_path(contact)
    assert_response :not_found
    patch contact_path(contact), params: { contact: { name: "Not permitted" } }
    assert_response :not_found
    delete contact_path(contact)
    assert_response :not_found
    post contacts_path, params: { contact: { name: "", email: "invalid" } }
    assert_redirected_to new_contact_path
    follow_redirect!
    assert inertia.props[:errors].key?("name")
    assert inertia.props[:errors].key?("email")
    sign_out
    get contacts_path
    assert_redirected_to new_session_path
  end

  test "invoice create update and detail props retain ordered separate contact snapshots" do
    contacts = [ { name: "Fictional Avery", email: "avery@example.test" }, { name: "Fictional Rowan", email: "rowan@example.test" } ]
    post invoices_path, params: { invoice: { number: "EXAMPLE-MULTIPLE", recipient: "Example Club", contacts: contacts, description: "Example fees", issued_on: "2031-09-15",
      line_items_attributes: [ { description: "Example services", quantity: 1, rate: "13.37" } ] } }, as: :json
    invoice = Invoice.last
    assert_redirected_to invoice_path(invoice)
    assert_equal contacts.map(&:stringify_keys), invoice.contacts
    get invoice_path(invoice)
    assert_equal invoice.contacts, inertia.props[:invoice][:contacts]
    assert_equal "Fictional Avery, Fictional Rowan", inertia.props[:invoice][:attention]
    patch invoice_path(invoice), params: { invoice: { contacts: contacts.reverse } }, as: :json
    assert_redirected_to invoice_path(invoice)
    assert_equal "rowan@example.test", invoice.reload.contact_email
    patch invoice_path(invoice), params: { invoice: { contacts: [] } }, as: :json
    assert_redirected_to invoice_path(invoice)
    assert_empty invoice.reload.contacts
    assert_equal "Example Club", invoice.attention
  end

  private
  def inertia_headers = { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
end
