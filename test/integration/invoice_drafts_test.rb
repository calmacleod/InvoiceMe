require "test_helper"

class InvoiceDraftsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    @data = { number: "", recipient: "Fictional Club", description: "", contact: "", recipient_address: "", issued_on: "", due_on: "", public_notes: "", private_notes: "Fictional private reminder",
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
    assert_equal draft.data, inertia.props[:draft_data]
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

  private
  def create_json(**extra)
    post invoice_drafts_path, params: { client_key: "fictional-client-key", season_id: @season.id, lock_version: 0, data: @data }.merge(extra), as: :json
  end
end
