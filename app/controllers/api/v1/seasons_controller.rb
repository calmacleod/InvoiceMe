module Api
  module V1
    class SeasonsController < BaseController
      def index
        render json: paginate(Season.order(year: :desc)) { |season| season.as_json }
      end

      def show
        render json: Season.find(params[:id])
      end

      def create
        season = Season.create!(season_params)
        render json: season, status: :created
      end

      def update
        season = Season.find(params[:id])
        season.update!(season_params)
        render json: season
      end

      private

      def season_params
        params.require(:season).permit(:year, :drive_folder_id, :pdf_folder_id, :spreadsheet_id, :sheet_name, :ledger_start_row, issuer: %i[name payable_to treasurer email address payment_instructions])
      end
    end
  end
end
