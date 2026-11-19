module GameBrowser
  private
  def game_search(picker: false)
    GameSearch.new(current_season.games, game_filter_params(picker: picker), user: Current.user)
  end

  def game_filter_params(picker: false)
    if picker
      params.fetch(:game_filters, ActionController::Parameters.new).permit(*GameSearch::FIELDS, home_team: [], away_team: [], code: []).to_h.tap do |filters|
        filters["q"] = params[:game_q] if params[:game_q].present? && !filters.key?("q")
      end
    else
      params.permit(*GameSearch::FIELDS, home_team: [], away_team: [], code: []).to_h
    end
  end

  def game_filter_choices = GameSearch.choices(current_season.games)

  def game_picker_props
    {
      game_options: -> {
        search = game_search(picker: true)
        order = GameOrder.new(params[:game_sort], params[:game_direction])
        page = WorkspacePage.new(order.apply(search.results), params[:game_page], params[:game_per_page])
        { games: game_list_props(page.records), pagination: page.props, query: search.filters["q"], filters: search.filters, errors: search.errors, filter_choices: game_filter_choices, sort: order.props }
      },
      matching_games: InertiaRails.optional { game_list_props(game_search(picker: true).results.order(:external_id, :id)) },
      game_detail: InertiaRails.optional { game_detail_props }
    }
  end

  def game_list_props(scope)
    games = scope.summaries.includes(:invoices, :invoice_groups).to_a
    drafts = game_workbench_references(games.map(&:id))
    games.map { |game| game_props(game, workbenches: drafts.fetch(game.id, [])) }
  end

  def game_workbench_references(ids)
    return {} if ids.empty?
    GameSearch.workbench_games(Current.user).where(season: current_season)
      .where("CAST(selected_games.value AS INTEGER) IN (?)", ids).distinct
      .pluck(Arel.sql("CAST(selected_games.value AS INTEGER)"), "invoice_drafts.id", "invoice_drafts.title")
      .each_with_object({}) { |(game_id, id, title), result| (result[game_id] ||= []) << { id: id, title: title } }
  end

  def game_detail_props
    game = current_season.games.includes(:invoices, :invoice_groups).find(params[:detail_id])
    game_props(game, detail: true, workbenches: game_workbench_references([ game.id ]).fetch(game.id, []))
  end
end
