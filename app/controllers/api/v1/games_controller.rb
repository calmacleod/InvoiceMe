module Api
  module V1
    class GamesController < BaseController
      def index
        season = Season.find(params.require(:season_id))
        search = GameSearch.new(season.games, params.permit(*GameSearch::FIELDS, home_team: [], away_team: [], code: []).to_h, user: @api_key.user)
        records = GameOrder.new(params[:sort], params[:direction]).apply(search.results)
        render json: paginate(records.includes(:invoices)) { |game| game.as_json.merge(invoices: game.invoices.as_json(only: %i[id number finalized_at])) }.merge(filter_errors: search.errors)
      end

      def show
        game = Game.find(params[:id])
        render json: game.as_json.merge(invoices: game.invoices.as_json(only: %i[id number finalized_at]))
      end

      def invoicing_status
        season = Season.find(params.require(:season_id))
        ids = Array(params.require(:game_ids)).map(&:to_s).uniq
        value = params[:already_invoiced]
        raise ArgumentError, "Select games and a boolean invoicing status" if ids.empty? || ids.any? { |id| !id.match?(/\A[1-9]\d*\z/) } || ![ true, false ].include?(value)
        games = season.games.where(id: ids)
        count = Game.transaction do
          raise ActiveRecord::RecordNotFound unless games.count == ids.size
          games.update_all(already_invoiced: value, updated_at: Time.current)
        end
        render json: { updated: count }
      end

      def import
        season = Season.find(params.require(:season_id))
        headers, rows, info = GameImport.read(params[:file])
        mapping = params[:mapping].present? ? JSON.parse(params[:mapping]) : GameImport.guess(headers)
        date_format = params[:date_format].presence || "%m/%d/%Y"
        raise ArgumentError, "Invalid date format" unless %w[%m/%d/%Y %d/%m/%Y %Y-%m-%d].include?(date_format)
        importer = GameImport.new(headers, rows, mapping, date_format: date_format).parse
        importer.commit!(season) if params[:commit] == "true" && importer.errors.empty?
        render json: { headers: headers, mapping: mapping, info: info, count: importer.games.size, games: importer.games.values.first(100), errors: importer.errors, committed: params[:commit] == "true" && importer.errors.empty? }
      rescue JSON::ParserError => e
        render_error(e.message, :unprocessable_entity)
      end
    end
  end
end
