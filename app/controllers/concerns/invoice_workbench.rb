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
      draft: draft&.metadata, draft_data: draft&.data.presence,
      workbenches: -> { open_workbenches.summaries.limit(20).map(&:metadata) },
      selected_games: -> {
        ids = draft&.data&.fetch("game_ids", nil) || invoice.game_ids
        current_season.games.where(id: ids).summaries.includes(:invoices).map { |game| game_props(game) }
      },
      game_options: -> {
        page = WorkspacePage.new(current_season.games.matching(params[:game_q]).order(date: :desc, external_id: :asc), params[:game_page])
        { games: page.records.summaries.includes(:invoices).map { |game| game_props(game) }, pagination: page.props, query: params[:game_q].to_s }
      }
    }
  end
end
