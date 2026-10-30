require "test_helper"
require_relative "../test_helpers/invoice_numbering_google"

class InvoiceDraftsTest < ActionDispatch::IntegrationTest
  include InvoiceNumberingGoogle
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    @data = { number: "", recipient: "Fictional Club", description: "", contacts: [], recipient_address: "", issued_on: "", due_on: "", public_notes: "", private_notes: "Fictional private reminder",
      game_ids: [], line_items_attributes: [ { key: "example-line", description: "", quantity: "", rate: "", position: 0, _destroy: false } ] }
  end

  test "incomplete edits persist without creating an invoice and new saves retry idempotently" do
    assert_difference "InvoiceDraft.count", 1 do
      assert_no_difference "Invoice.count" do
        create_json
        assert_response :success
        create_json
        assert_response :success
      end
    end
    draft = InvoiceDraft.last
    assert_equal "", draft.data["number"]
    assert_equal "Fictional private reminder", draft.data["private_notes"]
    get edit_invoice_draft_path(draft)
    assert_inertia_component "invoices/Edit"
    assert_equal draft.data.except("number").merge("number_suffix" => ""), inertia.props[:draft_data]
    assert_equal draft.id, inertia.props[:draft]["id"]
    assert_equal 0, LineItem.count
  end

  test "several blank drafts have separate identities and GET prefetch does not create anything" do
    ids = 2.times.map do
      post invoice_drafts_path
      assert_response :redirect
      InvoiceDraft.last.id
    end
    assert_equal 2, ids.uniq.size
    assert_no_difference "InvoiceDraft.count" do
      get new_invoice_path
      get edit_invoice_draft_path(ids.first)
      get invoice_drafts_path
    end
    assert_equal ids.sort, inertia.props[:drafts].map { |draft| draft["id"] }.sort
  end

  test "autosave revisions prevent stale tabs overwriting work and lost acknowledgements can retry" do
    create_json
    draft = InvoiceDraft.last
    changed = @data.merge(recipient: "Updated Fictional Club")
    patch invoice_draft_path(draft), params: { lock_version: 0, data: changed }, as: :json
    assert_response :success
    assert_equal 1, response.parsed_body["lock_version"]
    patch invoice_draft_path(draft), params: { lock_version: 0, data: changed }, as: :json
    assert_response :success
    assert_equal 1, response.parsed_body["lock_version"]
    patch invoice_draft_path(draft), params: { lock_version: 0, data: @data }, as: :json
    assert_response :conflict
    assert_equal "Updated Fictional Club", draft.reload.data["recipient"]
  end

  test "workbenches require login, belong to their author, and scope selected games to their year" do
    create_json
    draft = InvoiceDraft.last
    sign_out
    get edit_invoice_draft_path(draft)
    assert_redirected_to new_session_path
    sign_in_as(User.create!(email_address: "other@example.test", password: "fictional-password"))
    get edit_invoice_draft_path(draft)
    assert_response :not_found
    patch invoice_draft_path(draft), params: { lock_version: 0, data: @data }, as: :json
    assert_response :not_found
    sign_in_as(users(:one))
    other = Season.create!(year: 2035, sheet_name: "Example", issuer: @season.issuer)
    game = other.games.create!(external_id: "EXAMPLE-OTHER", date: Date.current)
    patch invoice_draft_path(draft), params: { lock_version: 0, data: @data.merge(game_ids: [ game.id ]) }, as: :json
    assert_response :unprocessable_entity
    assert_empty draft.reload.data["game_ids"]
  end

  test "preview validates raw data and creates a single invoice with exact line totals and game links" do
    create_json
    draft = InvoiceDraft.last
    assert_no_difference "Invoice.count" do
      post preview_invoice_draft_path(draft), params: { lock_version: 0 }
      assert_redirected_to edit_invoice_draft_path(draft)
    end
    game = @season.games.create!(external_id: "EXAMPLE-GAME", date: Date.current)
    valid = @data.merge(number: "EXAMPLE-2031", description: "Fictional fees", issued_on: "2031-02-17", game_ids: [ game.id ], line_items_attributes: [ { key: "example-line", description: "Example services", quantity: "2.5", rate: "13.37", position: 0, _destroy: false } ])
    patch invoice_draft_path(draft), params: { lock_version: 0, data: valid }, as: :json
    revision = response.parsed_body["lock_version"]
    assert_difference "Invoice.count", 1 do
      post preview_invoice_draft_path(draft), params: { lock_version: revision }
    end
    invoice = draft.reload.invoice
    assert_redirected_to invoice_path(invoice)
    assert_equal 3343, invoice.total_cents
    assert_equal [ game.id ], invoice.game_ids
    assert_equal "Fictional private reminder", invoice.private_notes
    assert_nil invoice.finalized_at
    assert_empty draft.data
    get edit_invoice_path(invoice)
    assert_redirected_to edit_invoice_draft_path(draft)
    get edit_invoice_draft_path(draft)
    assert_nil inertia.props[:draft_data]
    assert_equal invoice.line_items.first.id, inertia.props[:invoice][:line_items].first["id"]
    assert_no_difference "Invoice.count" do
      post preview_invoice_draft_path(draft), params: { lock_version: revision }
    end
    assert_redirected_to edit_invoice_draft_path(draft)
    line = invoice.line_items.first
    updated = valid.merge(line_items_attributes: [ { id: line.id, key: line.id, description: "Example revised", quantity: "3", rate: "13.37", position: 0, _destroy: false } ])
    patch invoice_draft_path(draft), params: { lock_version: draft.lock_version, data: updated }, as: :json
    assert_response :success
    assert_no_difference "LineItem.count" do
      post preview_invoice_draft_path(draft), params: { lock_version: response.parsed_body["lock_version"] }
    end
    assert_redirected_to invoice_path(invoice)
    assert_equal 4011, invoice.reload.total_cents
  end

  test "amount-only lines and reordered saved IDs survive autosave preview and reopening" do
    invoice = @season.invoices.create!(number: "EXAMPLE-ORDER", recipient: "Example Club", description: "Example fees", issued_on: "2031-02-17", line_items_attributes: [
      { description: "Example travel", amount_only: true, rate: "24.75", position: 0 },
      { description: "Example services", quantity: 2, rate: "13.37", position: 1 }
    ])
    travel, services = invoice.line_items.to_a
    data = @data.merge(number: invoice.number, description: invoice.description, issued_on: "2031-02-17", line_items_attributes: [
      { id: services.id, key: services.id, description: services.description, quantity: "2", rate: "13.37", amount_only: false, position: 0, _destroy: false },
      { id: travel.id, key: travel.id, description: travel.description, quantity: "", rate: "24.75", amount_only: true, position: 1, _destroy: false }
    ])
    post invoice_drafts_path, params: { invoice_id: invoice.id, client_key: "example-order", season_id: @season.id, data: data }, as: :json
    assert_response :success
    draft = InvoiceDraft.find(response.parsed_body.fetch("id"))
    assert_equal true, draft.data.dig("line_items_attributes", 1, "amount_only")
    assert_no_difference "LineItem.count" do
      post preview_invoice_draft_path(draft), params: { lock_version: draft.lock_version }
    end
    assert_redirected_to invoice_path(invoice)
    assert_equal [ services.id, travel.id ], invoice.reload.line_items.ids
    assert_equal 5149, invoice.total_cents
    get edit_invoice_draft_path(draft)
    assert_equal [ services.id, travel.id ], inertia.props[:invoice][:line_items].map { |item| item["id"] }
    assert_equal true, inertia.props[:invoice][:line_items].last["amount_only"]
  end

  test "existing invoice drafts autosave separately and finalized invoices reject further workbench writes" do
    invoice = @season.invoices.create!(number: "EXAMPLE-EXISTING", recipient: "Example", description: "Fictional", issued_on: Date.current,
      line_items_attributes: [ { description: "Example", quantity: 1, rate_cents: 1337 } ])
    create_json(invoice_id: invoice.id)
    draft = InvoiceDraft.last
    assert_equal "Example", invoice.reload.recipient
    invoice.finalize!
    patch invoice_draft_path(draft), params: { lock_version: 0, data: @data.merge(recipient: "Cannot overwrite") }, as: :json
    assert_response :conflict
    assert_equal "Fictional Club", draft.reload.data["recipient"]
    get invoice_drafts_path
    assert_empty inertia.props[:drafts]
    get edit_invoice_draft_path(draft)
    assert_redirected_to invoice_path(invoice)
  end

  test "deleting a workbench keeps its saved preview invoice and other workbenches" do
    invoice = @season.invoices.create!(number: "EXAMPLE-KEEP", recipient: "Example", description: "Fictional", issued_on: Date.current,
      line_items_attributes: [ { description: "Example", quantity: 1, rate_cents: 1337 } ])
    create_json(invoice_id: invoice.id)
    draft = InvoiceDraft.last
    post invoice_drafts_path
    other = InvoiceDraft.last
    assert_difference "InvoiceDraft.count", -1 do
      assert_no_difference "Invoice.count" do
        delete invoice_draft_path(draft)
      end
    end
    assert InvoiceDraft.exists?(other.id)
    assert Invoice.exists?(invoice.id)
  end

  test "a new workbench cannot reuse another invoice's line item IDs" do
    invoice = @season.invoices.create!(number: "EXAMPLE-FOREIGN-LINE", recipient: "Example", description: "Fictional", issued_on: Date.current,
      line_items_attributes: [ { description: "Example", quantity: 1, rate_cents: 1337 } ])
    @data[:line_items_attributes][0][:id] = invoice.line_items.first.id
    assert_no_difference "InvoiceDraft.count" do
      create_json
      assert_response :unprocessable_entity
    end
    assert_equal 1337, invoice.reload.total_cents
  end

  test "explicitly editing a saved draft opens a workbench once without changing the invoice" do
    invoice = @season.invoices.create!(number: "EXAMPLE-CLAIM", recipient: "Example", description: "Fictional", issued_on: Date.current,
      line_items_attributes: [ { description: "Example", quantity: 1, rate_cents: 1337 } ])
    assert_difference "InvoiceDraft.count", 1 do
      2.times { post invoice_drafts_path, params: { invoice_id: invoice.id } }
    end
    assert_redirected_to edit_invoice_draft_path(InvoiceDraft.find_by!(invoice: invoice))
    assert_equal 1337, invoice.reload.total_cents
    invoice.finalize!
    post invoice_drafts_path, params: { invoice_id: invoice.id }
    assert_redirected_to invoice_path(invoice)
  end

  test "contacts autosave incomplete emails but preview validates them and retains order through reopening and removal" do
    contacts = [ { name: "Fictional Avery", email: "not-yet-valid" }, { name: "Fictional Rowan", email: "rowan@example.test" } ]
    @data.merge!(number: "EXAMPLE-CONTACTS", description: "Example fees", issued_on: "2031-09-15", contacts: contacts,
      line_items_attributes: [ { key: "example", description: "Example services", quantity: "1", rate: "13.37", position: 0, _destroy: false } ])
    create_json
    assert_response :success
    draft = InvoiceDraft.last
    assert_equal contacts.map(&:stringify_keys), draft.data["contacts"]
    assert_no_difference "Invoice.count" do
      post preview_invoice_draft_path(draft), params: { lock_version: draft.lock_version }
      assert_redirected_to edit_invoice_draft_path(draft)
    end
    get edit_invoice_draft_path(draft)
    assert inertia.props[:errors].key?("contacts")
    assert_equal contacts.map(&:stringify_keys), inertia.props[:draft_data]["contacts"]
    contacts.first[:email] = "avery@example.test"
    patch invoice_draft_path(draft), params: { lock_version: draft.lock_version, data: @data }, as: :json
    assert_response :success
    post preview_invoice_draft_path(draft), params: { lock_version: response.parsed_body["lock_version"] }
    invoice = draft.reload.invoice
    assert_redirected_to invoice_path(invoice)
    get edit_invoice_draft_path(draft)
    assert_equal contacts.map(&:stringify_keys), inertia.props[:invoice][:contacts]
    line = invoice.line_items.first
    @data[:line_items_attributes][0].merge!(id: line.id, key: line.id)
    [ contacts.reverse, [ contacts.last ], [] ].each do |selection|
      patch invoice_draft_path(draft), params: { lock_version: draft.reload.lock_version, data: @data.merge(contacts: selection) }, as: :json
      assert_response :success
      post preview_invoice_draft_path(draft), params: { lock_version: response.parsed_body["lock_version"] }
      assert_redirected_to invoice_path(invoice)
      assert_equal selection.map(&:stringify_keys), invoice.reload.contacts
    end
  end

  test "legacy combined contacts open as separate fields and preview without losing their email" do
    @data.delete(:contacts)
    @data.merge!(number: "EXAMPLE-LEGACY-CONTACT", description: "Example fees", issued_on: "2031-09-15", contact: "Fictional Avery <avery@example.test>",
      line_items_attributes: [ { key: "example", description: "Example services", quantity: "1", rate: "13.37", position: 0, _destroy: false } ])
    create_json
    draft = InvoiceDraft.last
    get edit_invoice_draft_path(draft)
    assert_equal [ { "name" => "Fictional Avery", "email" => "avery@example.test" } ], inertia.props[:draft_data]["contacts"]
    refute inertia.props[:draft_data].key?("contact")
    post preview_invoice_draft_path(draft), params: { lock_version: draft.lock_version }
    invoice = draft.reload.invoice
    assert_redirected_to invoice_path(invoice)
    assert_equal "Fictional Avery", invoice.attention
    assert_equal "avery@example.test", invoice.contact_email
  end

  test "suffix-only workbenches allocate on preview retain the prefix on edits and preserve data when Google fails" do
    @data = @data.except(:number).merge(number_suffix: "Fictional_Club", description: "Example fees", issued_on: "2031-09-15",
      line_items_attributes: [ { key: "example", description: "Fictional services", quantity: "1", rate: "13.37", position: 0, _destroy: false } ])
    create_json
    draft = InvoiceDraft.last
    assert_equal 0, @season.reload.last_invoice_sequence
    get edit_invoice_draft_path(draft)
    assert_equal "Fictional_Club", inertia.props[:draft_data]["number_suffix"]
    assert_nil inertia.props[:invoice][:number_prefix]
    @numbering_api.define_singleton_method(:values) { |*| raise GoogleApi::TransientError, "Example Google outage" }
    assert_no_difference "Invoice.count" do
      post preview_invoice_draft_path(draft), params: { lock_version: draft.lock_version }
    end
    assert_redirected_to edit_invoice_draft_path(draft)
    assert_equal "Example Google outage", flash[:alert]
    assert_equal "Fictional_Club", draft.reload.data["number_suffix"]
    @numbering_api.singleton_class.remove_method(:values)
    post preview_invoice_draft_path(draft), params: { lock_version: draft.lock_version }
    invoice = draft.reload.invoice
    assert_redirected_to invoice_path(invoice)
    assert_equal "2026_05_Fictional_Club", invoice.number
    patch invoice_path(invoice), params: { invoice: { number_suffix: "Updated_Info" } }
    assert_equal "2026_05_Updated_Info", invoice.reload.number
    assert_equal 5, @season.reload.last_invoice_sequence
    get edit_invoice_draft_path(draft)
    assert_equal "2026_05_", inertia.props[:invoice][:number_prefix]
    assert_equal "Updated_Info", inertia.props[:invoice][:number_suffix]
  end

  private
  def create_json(**extra)
    post invoice_drafts_path, params: { client_key: "fictional-client-key", season_id: @season.id, lock_version: 0, data: @data }.merge(extra), as: :json
  end
end
