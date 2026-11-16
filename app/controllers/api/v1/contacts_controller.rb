module Api
  module V1
    class ContactsController < BaseController
      def index
        render json: paginate(@api_key.user.contacts.searching(params[:q]).order(:name, :id)) { |contact| contact.as_json }
      end

      def show
        render json: contact
      end

      def create
        record = @api_key.user.contacts.create!(contact_params)
        render json: record, status: :created
      end

      def update
        contact.update!(contact_params)
        render json: contact
      end

      def destroy
        contact.destroy!
        head :no_content
      end

      private

      def contact = @contact ||= @api_key.user.contacts.find(params[:id])
      def contact_params = params.require(:contact).permit(*Contact::FIELDS)
    end
  end
end
