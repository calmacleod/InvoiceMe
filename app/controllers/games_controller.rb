class GamesController < ApplicationController
  before_action :need_season
  def index
    @games = current_season.games.includes(:invoices).order(date: :desc, external_id: :asc)
    @games = @games.where("code LIKE :q OR external_id LIKE :q OR home_team LIKE :q OR away_team LIKE :q", q: "%#{Game.sanitize_sql_like(params[:q].to_s)}%") if params[:q].present?
  end
  def new; end
  def upload
    headers, rows = GameImport.read(params[:file])
    session[:import_id] = SecureRandom.hex(16)
    FileUtils.mkdir_p(Rails.root.join("tmp/imports"))
    File.write(import_path, JSON.generate(headers: headers, rows: rows, season_id: current_season.id))
    @headers, @rows = headers, rows
    @mapping = GameImport.guess(headers).merge(current_season.import_mapping.slice(*GameImport::FIELDS).select { |_, v| headers.include?(v) })
    render :map
  rescue ArgumentError, CSV::MalformedCSVError, Zip::Error => e
    redirect_to new_game_path, alert: e.message
  end
  def preview
    data = import_data
    @headers, @rows = data.fetch("headers"), data.fetch("rows")
    @mapping = params.require(:mapping).permit(*GameImport::FIELDS, official_columns: [:name, :amount]).to_h
    @date_format = params[:date_format]
    raise ArgumentError, "Choose a date format" unless %w[%m/%d/%Y %d/%m/%Y %Y-%m-%d].include?(@date_format)
    @import = GameImport.new(@headers, @rows, @mapping, date_format: @date_format).parse
    File.write(import_path, JSON.generate(data.merge("mapping" => @mapping, "date_format" => @date_format)))
    render :preview
  rescue ArgumentError => e
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
    send_data "Game #,Game Code,Date,Time,Home Team,Away Team,Location,Official,Amount Paid\n12345,CJFL,2026-10-25,13:00,Ottawa,Kingston,TD Place,Example Official,100.00\n", filename: "horizon-example.csv", type: "text/csv"
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
