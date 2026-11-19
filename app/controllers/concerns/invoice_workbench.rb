module InvoiceWorkbench
  private
  def fresh_invoice
    current_season.invoices.new(issued_on: Date.current).tap { |invoice| invoice.line_items.build(quantity: 1) }
  end

  def open_workbenches
    InvoiceDraft.where(user: Current.user, season: current_season).open_work
  end

  def render_invoice_editor(invoice, draft: nil)
    group = draft&.invoice_group || invoice.invoice_group
    render inertia: "invoices/Edit", props: game_picker_props.merge(
      invoice: -> { invoice_props(invoice, detail: true) },
      draft: draft&.metadata, draft_data: draft&.invoice_data.presence,
      invoice_group: -> {
        group && group.as_json(only: %i[id name]).merge(game_count: group.invoice_group_games.count, entries: invoice_group_entries(group))
      },
      workbenches: -> { open_workbenches.summaries.limit(20).map(&:metadata) },
      selected_games: -> {
        ids = group ? [] : draft&.data&.fetch("game_ids", nil) || invoice.game_ids
        game_list_props(current_season.games.where(id: ids))
      },
      contact_options: InertiaRails.optional {
        scope = Current.user.contacts.searching(params[:contact_q]).order(:name, :id)
        page = WorkspacePage.new(scope, params[:contact_page], params[:contact_per_page])
        { contacts: page.records.map(&:recipient_props), pagination: page.props, query: params[:contact_q].to_s }
      }
    ).tap { |props| props[:game_options] = nil if group }
  end

  def invoice_group_entries(group)
    drafts = open_workbenches.where(invoice_group: group).summaries.to_a
    linked_drafts = drafts.index_by(&:invoice_id)
    group.invoices.order(:id).includes(:line_items, :payments).map do |invoice|
      { invoice: invoice_props(invoice), draft: linked_drafts[invoice.id]&.metadata }
    end + drafts.select { |draft| draft.invoice_id.nil? }.map { |draft| { invoice: nil, draft: draft.metadata } }
  end
end
