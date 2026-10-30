module InvoiceWorkbench
  private
  def fresh_invoice
    current_season.invoices.new(number: "#{current_season.year}_", issued_on: Date.current).tap { |invoice| invoice.line_items.build(quantity: 1) }
  end

  def open_workbenches
    InvoiceDraft.where(user: Current.user, season: current_season).open_work
  end

  def render_invoice_editor(invoice, draft: nil)
    render inertia: "invoices/Edit", props: {
      invoice: -> { invoice_props(invoice, detail: true) },
      draft: draft&.metadata, draft_data: draft&.invoice_data.presence,
      workbenches: -> { open_workbenches.summaries.limit(20).map(&:metadata) },
      selected_games: -> {
        ids = draft&.data&.fetch("game_ids", nil) || invoice.game_ids
        game_list_props(current_season.games.where(id: ids))
      },
      game_options: -> {
        search = game_search(picker: true)
        order = GameOrder.new(params[:game_sort], params[:game_direction])
        page = WorkspacePage.new(order.apply(search.results), params[:game_page], params[:game_per_page])
        { games: game_list_props(page.records), pagination: page.props, query: search.filters["q"], filters: search.filters, errors: search.errors, filter_choices: game_filter_choices, sort: order.props }
      },
      matching_games: InertiaRails.optional { game_list_props(game_search(picker: true).results.order(:external_id, :id)) },
      game_detail: InertiaRails.optional { game_detail_props },
      contact_options: InertiaRails.optional {
        scope = Current.user.contacts.searching(params[:contact_q]).order(:name, :id)
        page = WorkspacePage.new(scope, params[:contact_page], params[:contact_per_page])
        { contacts: page.records.map(&:recipient_props), pagination: page.props, query: params[:contact_q].to_s }
      }
    }
  end
end
