require "test_helper"
require_relative "../test_helpers/invoice_numbering_google"

class InvoiceGroupsTest < ActionDispatch::IntegrationTest
  include InvoiceNumberingGoogle

  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    post select_year_path, params: { id: @season.id }
    @game, @second_game = %w[EXAMPLE-ONE EXAMPLE-TWO].map do |external_id|
      @season.games.create!(external_id: external_id, date: Date.new(2031, 9, 15))
    end
  end

  test "one group supports independently previewed invoices with the same games" do
    post invoice_groups_path, params: { game_ids: [ @game.id ] }
    group = InvoiceGroup.last
    assert_redirected_to invoice_group_path(group)
    assert_equal [ @game.id ], group.game_ids

    league = add_draft(group, recipient: "Example League", description: "Officials")
    club = add_draft(group, recipient: "Example Club", description: "Stick crew")
    get edit_invoice_draft_path(club)
    assert_equal group.id, inertia.props[:invoice_group]["id"]
    assert_equal [ league.id, club.id ].sort, inertia.props[:invoice_group][:entries].map { |entry| entry[:draft]["id"] }.sort
    assert_nil inertia.props[:game_options]

    post preview_invoice_draft_path(league), params: { lock_version: league.lock_version }
    league_invoice = league.reload.invoice
    assert_redirected_to invoice_path(league_invoice)
    assert_equal [ @game.id ], league_invoice.game_ids

    revision = group.lock_version
    patch invoice_group_path(group), params: { name: "Example September games", game_ids: [ @game.id, @second_game.id ], lock_version: revision }
    assert_redirected_to invoice_group_path(group)
    assert_equal [ @game.id, @second_game.id ].sort, league_invoice.reload.game_ids.sort
    assert_operator group.reload.lock_version, :>, revision

    post preview_invoice_draft_path(club), params: { lock_version: club.lock_version }
    club_invoice = club.reload.invoice
    assert_redirected_to invoice_path(club_invoice)
    assert_equal league_invoice.game_ids.sort, club_invoice.game_ids.sort
    assert_equal [ "Officials", "Stick crew" ], [ league_invoice, club_invoice ].map { |invoice| invoice.line_items.first.description }
    assert_equal [ "Example League", "Example Club" ], [ league_invoice, club_invoice ].map(&:recipient)
    assert_not_equal league_invoice.number, club_invoice.number
    assert_equal [ league_invoice.id, club_invoice.id ].sort, @second_game.invoices.ids.sort

    patch invoice_path(club_invoice), params: { invoice: { game_ids: [ @game.id ] } }
    assert_redirected_to edit_invoice_path(club_invoice)
    assert_equal group.game_ids.sort, club_invoice.reload.game_ids.sort

    patch invoice_group_path(group), params: { name: "Stale change", game_ids: [ @game.id ], lock_version: revision }
    assert_equal "Example September games", group.reload.name
    assert_equal 2, group.games.count

    league_invoice.finalize!
    patch invoice_group_path(group), params: { name: group.name, game_ids: [ @game.id ], lock_version: group.lock_version }
    assert_equal 2, group.reload.games.count
    assert_equal 2, club_invoice.reload.games.count
    get invoice_group_path(group)
    assert_equal true, inertia.props[:group][:games_locked]
    assert_equal [ club_invoice.id, league_invoice.id ].sort, inertia.props[:entries].map { |entry| entry[:invoice]["id"] }.sort
  end

  test "group an autosaved draft without losing recipients or line items" do
    draft = users(:one).invoice_drafts.create!(season: @season, client_key: "example-standalone", data: data_for("Example Club", "Stick crew").merge(game_ids: [ @game.id ]))
    assert_difference "InvoiceGroup.count" do
      post invoice_groups_path, params: { draft_id: draft.id }
    end
    draft.reload
    assert_redirected_to invoice_group_path(draft.invoice_group)
    assert_equal "Example Club", draft.data["recipient"]
    assert_equal "Stick crew", draft.data.dig("line_items_attributes", 0, "description")
    assert_not draft.data.key?("game_ids")
    assert_equal [ @game.id ], GameSearch.new(@season.games, { "link_status" => "workbench" }, user: users(:one)).results.ids

    patch invoice_draft_path(draft), params: { invoice_group_id: nil, lock_version: draft.lock_version, data: draft.data }, as: :json
    assert_response :conflict

    assert_no_difference "InvoiceGroup.count" do
      post invoice_groups_path, params: { draft_id: draft.id }
    end
    assert_redirected_to invoice_group_path(draft.invoice_group)

    sign_out
    sign_in_as(users(:two))
    get invoice_group_path(draft.invoice_group)
    assert_empty inertia.props[:entries]
    post invoice_groups_path, params: { draft_id: draft.id }
    assert_response :not_found
  end

  test "existing invoices can join a group with the exact same selection" do
    league = create_invoice("EXAMPLE-LEAGUE", [ @game.id ])
    club = create_invoice("EXAMPLE-CLUB", [ @game.id ])
    extra = create_invoice("EXAMPLE-EXTRA", [ @game.id, @second_game.id ])
    league.finalize!

    post invoice_groups_path, params: { invoice_id: league.id }
    group = league.reload.invoice_group
    assert_redirected_to invoice_group_path(group)
    assert group.games_locked?
    get add_existing_invoice_group_path(group), params: { q: "EXAMPLE-CLUB" }
    assert_equal [ club.id ], inertia.props[:invoices].map { |invoice| invoice["id"] }

    post attach_invoice_invoice_group_path(group), params: { invoice_id: extra.id }
    assert_nil extra.reload.invoice_group_id
    post attach_invoice_invoice_group_path(group), params: { invoice_id: club.id }
    assert_equal group.id, club.reload.invoice_group_id
    assert_equal [ @game.id ], club.game_ids
    assert_equal 2, group.invoices.count

    get invoice_groups_path
    assert_equal 2, inertia.props[:groups].first[:invoice_count]
    get games_path(link_status: "linked")
    game = inertia.props[:games].find { |result| result["id"] == @game.id }
    assert_equal group.id, game[:invoice_groups].first["id"]
  end

  test "an editable invoice can adopt the group games only after reviewing the changes" do
    invoice = create_invoice("EXAMPLE-EXISTING", [ @second_game.id ])
    draft = users(:one).invoice_drafts.create!(season: @season, invoice: invoice, client_key: "example-review",
      data: { recipient: "Example saved edit", game_ids: [ @second_game.id ] })
    group = InvoiceGroup.start!(season: @season, game_ids: [ @game.id ])
    original_total = invoice.total_cents
    original_line_item_ids = invoice.line_items.ids

    get add_existing_invoice_group_path(group)
    assert_equal [ invoice.id ], inertia.props[:invoices].map { |item| item["id"] }
    get add_existing_invoice_group_path(group, invoice_id: invoice.id)
    review = inertia.props[:review]
    assert_equal [ @game.id ], review[:games_added].map { |game| game[:id] }
    assert_equal [ @second_game.id ], review[:games_removed].map { |game| game[:id] }
    assert_nil review[:blocked_reason]

    post attach_invoice_invoice_group_path(group), params: { invoice_id: invoice.id }
    assert_redirected_to add_existing_invoice_group_path(group, invoice_id: invoice.id)
    assert_nil invoice.reload.invoice_group_id
    assert_equal [ @second_game.id ], invoice.game_ids

    post attach_invoice_invoice_group_path(group), params: { invoice_id: invoice.id, review_token: review[:token] }
    assert_redirected_to invoice_group_path(group)
    assert_equal group.id, invoice.reload.invoice_group_id
    assert_equal [ @game.id ], invoice.game_ids
    assert_equal original_total, invoice.total_cents
    assert_equal original_line_item_ids, invoice.line_items.ids
    assert_equal group.id, draft.reload.invoice_group_id
    assert_equal "Example saved edit", draft.invoice_data["recipient"]
    assert_not draft.invoice_data.key?("game_ids")
  end

  test "the attachment review must be refreshed if shared games change" do
    invoice = create_invoice("EXAMPLE-STALE-REVIEW", [])
    group = InvoiceGroup.start!(season: @season, game_ids: [ @game.id ])
    get add_existing_invoice_group_path(group, invoice_id: invoice.id)
    token = inertia.props[:review][:token]
    group.update_selection!(name: group.name, game_ids: [ @second_game.id ], revision: group.lock_version)

    post attach_invoice_invoice_group_path(group), params: { invoice_id: invoice.id, review_token: token }
    assert_redirected_to add_existing_invoice_group_path(group, invoice_id: invoice.id)
    assert_nil invoice.reload.invoice_group_id
    assert_empty invoice.game_ids
  end

  test "a finalized invoice can be linked when it has no games and retains existing game history otherwise" do
    unlinked = create_invoice("EXAMPLE-FINAL-UNLINKED", [])
    different = create_invoice("EXAMPLE-FINAL-DIFFERENT", [ @second_game.id ])
    [ unlinked, different ].each(&:finalize!)
    group = InvoiceGroup.start!(season: @season, game_ids: [ @game.id ])

    get add_existing_invoice_group_path(group, invoice_id: different.id)
    assert_match "has been finalized", inertia.props[:review][:blocked_reason]
    post attach_invoice_invoice_group_path(group), params: { invoice_id: different.id, review_token: inertia.props[:review][:token] }
    assert_nil different.reload.invoice_group_id
    assert_equal [ @second_game.id ], different.game_ids

    get add_existing_invoice_group_path(group, invoice_id: unlinked.id)
    review = inertia.props[:review]
    assert_nil review[:blocked_reason]
    finalization = unlinked.finalized_at
    post attach_invoice_invoice_group_path(group), params: { invoice_id: unlinked.id, review_token: review[:token] }
    assert_redirected_to invoice_group_path(group)
    assert_equal group.id, unlinked.reload.invoice_group_id
    assert_equal [ @game.id ], unlinked.game_ids
    assert_equal finalization, unlinked.finalized_at
    assert group.games_locked?
  end

  test "a group requires games from its own year" do
    other = Season.create!(year: 2039, sheet_name: "Example", issuer: @season.issuer)
    foreign_game = other.games.create!(external_id: "EXAMPLE-OTHER", date: Date.new(2039, 9, 15))
    assert_no_difference "InvoiceGroup.count" do
      post invoice_groups_path, params: { game_ids: [ foreign_game.id ] }
      assert_redirected_to games_path
    end
  end

  private

  def add_draft(group, recipient:, description:)
    post invoice_drafts_path, params: { invoice_group_id: group.id }
    draft = InvoiceDraft.last
    assert_redirected_to edit_invoice_draft_path(draft)
    patch invoice_draft_path(draft), params: {
      lock_version: draft.lock_version,
      data: data_for(recipient, description).merge(game_ids: [ @second_game.id ])
    }, as: :json
    assert_response :success
    assert_not draft.reload.data.key?("game_ids")
    draft
  end

  def data_for(recipient, description)
    {
      number_suffix: recipient.tr(" ", "-"), recipient: recipient, description: description, issued_on: "2031-09-15",
      line_items_attributes: [ { key: "example-line", description: description, quantity: "1", rate: "45.00", position: 0, _destroy: false } ]
    }
  end

  def create_invoice(number, ids)
    @season.invoices.create!(number: number, recipient: "Example Club", description: "Example fees", issued_on: "2031-09-15", game_ids: ids,
      line_items_attributes: [ { description: "Example line", quantity: 1, rate: "45.00" } ])
  end
end
