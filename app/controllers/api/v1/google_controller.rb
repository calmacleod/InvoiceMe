module Api
  module V1
    class GoogleController < BaseController
      def show
        render json: { configured: GoogleApi.configured?, email: GoogleConnection.first&.email }
      end

      def destroy
        GoogleConnection.destroy_all
        head :no_content
      end
    end
  end
end
