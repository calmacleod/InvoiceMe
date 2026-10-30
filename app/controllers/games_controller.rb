class GamesController < ApplicationController
  before_action :need_season
  def index
    search = -> { @game_search ||= GameSearch.new(current_season.games, game_filter_params.presence || Current.user.game_filters.fetch(current_season.id.to_s, {}), user: Current.user) }
    order = GameOrder.new(params[:sort], params[:direction])
    page = -> { @game_page ||= WorkspacePage.new(order.apply(search.call.results), params[:page], params[:per_page]) }
    render inertia: "games/Index", props: {
      games: -> { game_list_props(page.call.records) },
      pagination: -> { page.call.props }, total_count: -> { current_season.games.count }, query: -> { search.call.filters["q"] },
      filters: -> { search.call.filters }, filter_errors: -> { page.call; search.call.errors },
      filter_choices: -> { game_filter_choices },
      sort: order.props,
      matching_game_ids: InertiaRails.optional { search.call.results.reorder(nil).ids },
      game_detail: InertiaRails.optional { game_detail_props }
    }
  end
  def filters
    search = game_search
    search.results
    view = params.permit(:sort, :direction, :per_page, :season_id).to_h
    return redirect_to games_path(view.merge(search.filters)), status: :see_other if search.errors.any?

    Current.user.with_lock do
      saved = Current.user.game_filters.except(current_season.id.to_s)
      saved[current_season.id.to_s] = search.filters unless search.filters.values.all?(&:blank?)
      Current.user.update!(game_filters: saved)
    end
    redirect_to games_path(view), status: :see_other
  end
  def invoicing_status
    ids = Array(params.permit(game_ids: [])[:game_ids]).map(&:to_s).uniq
    value = params[:already_invoiced].to_s
    raise ActionController::BadRequest, "Select games and an invoicing status" if ids.empty? || ids.any? { |id| !id.match?(/\A[1-9]\d*\z/) } || !%w[true false].include?(value)

    games = current_season.games.where(id: ids)
    count = Game.transaction do
      raise ActiveRecord::RecordNotFound unless games.count == ids.size
      games.update_all(already_invoiced: value == "true", updated_at: Time.current)
    end
    message = value == "true" ? "Marked #{count} games as already invoiced." : "Cleared the already-invoiced mark on #{count} games."
    redirect_to games_path(game_filter_params.merge(params.permit(:sort, :direction, :per_page, :page, :season_id).to_h)), status: :see_other, notice: message
  end
  def new
    render inertia: "games/Upload"
  end
  def upload
    headers, rows, info = GameImport.read(params[:file])
    session[:import_id] = SecureRandom.hex(16)
    FileUtils.mkdir_p(Rails.root.join("tmp/imports"))
    File.write(import_path, JSON.generate(headers: headers, rows: rows, info: info, season_id: current_season.id))
    redirect_to map_games_path, status: :see_other
  rescue ArgumentError, CSV::MalformedCSVError, Zip::Error => e
    redirect_to new_game_path, alert: e.message
  end
  def map
    data = import_data
    @headers, @rows, @import_info = data.fetch("headers"), data.fetch("rows"), data.fetch("info", {})
    @mapping = GameImport.guess(@headers).merge(current_season.import_mapping.slice(*GameImport::FIELDS).select { |_, v| @headers.include?(v) })
    render inertia: "games/Map", props: { headers: @headers, rows: @rows.first(5), row_count: @rows.size, info: @import_info, mapping: @mapping, fields: GameImport::FIELDS, required: GameImport::REQUIRED }
  rescue ArgumentError => e
    redirect_to new_game_path, alert: e.message
  end
  def preview
    data = import_data
    mapping = params.require(:mapping).permit(*GameImport::FIELDS, official_columns: [ :name, :amount, :position ]).to_h
    date_format = params[:date_format]
    raise ArgumentError, "Choose a date format" unless %w[%m/%d/%Y %d/%m/%Y %Y-%m-%d].include?(date_format)
    File.write(import_path, JSON.generate(data.merge("mapping" => mapping, "date_format" => date_format)))
    redirect_to review_games_path, status: :see_other
  rescue ArgumentError => e
    redirect_to new_game_path, alert: e.message
  end
  def review
    data = import_data
    @import_info = data.fetch("info", {})
    @import = GameImport.new(data.fetch("headers"), data.fetch("rows"), data.fetch("mapping"), date_format: data.fetch("date_format")).parse
    render inertia: "games/Review", props: { games: @import.games.values.first(100), total_count: @import.games.size, errors_list: @import.errors.first(30), totals: { officials: @import.games.values.sum { |game| game[:officials].size }, fees: @import.games.values.sum { |game| game[:fees_cents] } } }
  rescue ArgumentError, KeyError => e
    redirect_to new_game_path, alert: e.message
  end
  def commit
    data = import_data
    importer = GameImport.new(data.fetch("headers"), data.fetch("rows"), data.fetch("mapping"), date_format: data.fetch("date_format")).parse
    importer.commit!(current_season)
    File.delete(import_path)
    session.delete(:import_id)
    redirect_to games_path, notice: "Imported #{importer.games.size} games. Existing games were updated by game number."
  rescue ArgumentError => e
    redirect_to new_game_path, alert: e.message
  end
  def sample
    send_data "Game ID#,Game Date,Game Time,Home,Away,Field,Game Code,Paid By Team,# of Officials,Game Length (min),Officials/Positions\n900000001,02/17/2031,1:00pm,Example Alpha,Example Bravo,Fictional Field,TEST-LEAGUE,No,2,120,Example Official,Referee,$13.37,Second Official,Umpire,$22.22\n", filename: "horizon-example.csv", type: "text/csv"
  end
  private
  def import_path
    id = session[:import_id].to_s
    raise ArgumentError, "Upload a file to start an import" unless id.match?(/\A[0-9a-f]{32}\z/)
    Rails.root.join("tmp/imports/#{id}.json")
  end
  def import_data
    raise ArgumentError, "Import expired; upload the file again" unless File.exist?(import_path) && File.mtime(import_path) > 2.hours.ago
    data = JSON.parse(File.read(import_path))
    raise ArgumentError, "Switch back to the year you uploaded this file for" unless data["season_id"] == current_season.id
    data
  end
end
