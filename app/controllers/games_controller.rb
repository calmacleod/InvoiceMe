class GamesController < ApplicationController
  before_action :need_season
  def index
    page = -> { @game_page ||= WorkspacePage.new(current_season.games.matching(params[:q]).order(date: :desc, external_id: :asc), params[:page]) }
    render inertia: "games/Index", props: {
      games: -> { page.call.records.summaries.includes(:invoices).map { |game| game_props(game) } },
      pagination: -> { page.call.props }, total_count: -> { current_season.games.count }, query: params[:q].to_s,
      game_detail: InertiaRails.optional { game_props(current_season.games.includes(:invoices).find(params[:detail_id]), detail: true) }
    }
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
