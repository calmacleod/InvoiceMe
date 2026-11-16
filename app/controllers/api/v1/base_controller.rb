module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_key!
      before_action :require_write_access!
      rescue_from ActiveRecord::RecordNotFound, with: -> { render_error("Not found", :not_found) }
      rescue_from ActiveRecord::RecordInvalid, with: ->(e) { render_error(e.record.errors.full_messages, :unprocessable_entity) }
      rescue_from ActiveRecord::RecordNotDestroyed, with: ->(e) { render_error(e.record.errors.full_messages, :unprocessable_entity) }
      rescue_from ActionController::ParameterMissing, ArgumentError, with: ->(e) { render_error(e.message, :unprocessable_entity) }
      rescue_from ActiveRecord::StaleObjectError, with: -> { render_error("Draft has changed; reload it and retry", :conflict) }
      rescue_from GoogleApi::Error, with: ->(e) { render_error(e.message, :unprocessable_entity) }

      private

      def authenticate_key!
        token = request.authorization.to_s[/\ABearer (im_[A-Za-z0-9_-]+)\z/, 1]
        @api_key = ApiKey.includes(:user).find_by(token_digest: Digest::SHA256.hexdigest(token)) if token
        return render_error("Invalid or missing API key", :unauthorized) unless @api_key && !@api_key.revoked_at

        @api_key.update_column(:last_used_at, Time.current) if @api_key.last_used_at.nil? || @api_key.last_used_at < 5.minutes.ago
      end

      def require_write_access!
        render_error("API key is read-only", :forbidden) if !request.get? && !request.head? && !@api_key.write_access
      end

      def render_error(message, status)
        render json: { error: message }, status: status
      end

      def paginate(scope)
        page = WorkspacePage.new(scope, params[:page], params[:per_page])
        { data: page.records.map { |record| yield record }, pagination: page.props }
      end

      def invoice_json(invoice)
        invoice.as_json(except: %i[created_at updated_at contacts]).merge(
          status: invoice.status, total_cents: invoice.total_cents, received_cents: invoice.received_cents,
          owed_cents: invoice.owed_cents, contacts: invoice.contacts, issuer: invoice.issuer,
          line_items: invoice.line_items.map { |item| item.as_json.merge(rate: item.rate, total_cents: item.total_cents) },
          game_ids: invoice.games.ids, payments: invoice.payments.as_json,
          export: invoice.invoice_exports.order(id: :desc).first&.progress
        )
      end
    end
  end
end
