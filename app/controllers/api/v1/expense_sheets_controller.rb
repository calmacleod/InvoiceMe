module Api
  module V1
    class ExpenseSheetsController < BaseController
      def show
        render json: ExpenseSheetSync.for_season(season)
      end

      def create
        ExpenseSheetSync.enqueue_for(season)
        render json: ExpenseSheetSync.for_season(season.reload), status: :accepted
      end

      private

      def season = @season ||= Season.find(params[:season_id])
    end
  end
end
