module Api
  module V1
    class InvoicePaymentChecksController < BaseController
      def show
        render json: InvoicePaymentCheck.for_season(season)
      end

      def create
        render json: InvoicePaymentCheck.enqueue_for(season).progress, status: :accepted
      end

      private

      def season = Season.find(params[:season_id])
    end
  end
end
