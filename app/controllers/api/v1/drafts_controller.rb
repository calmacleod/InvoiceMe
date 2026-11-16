module Api
  module V1
    class DraftsController < BaseController
      def index
        scope = @api_key.user.invoice_drafts.where(season: Season.find(params.require(:season_id))).open_work
        render json: paginate(scope) { |draft| draft.as_json }
      end

      def show
        render json: draft
      end

      def create
        season = Season.find(params.require(:season_id))
        record = @api_key.user.invoice_drafts.new(season: season, client_key: params[:client_key].presence || SecureRandom.uuid)
        record.invoice = season.invoices.find(params[:invoice_id]) if params[:invoice_id].present?
        record.data = draft_data
        record.invoice ? record.invoice.with_lock { record.save! } : record.save!
        render json: record, status: :created
      rescue ActiveRecord::RecordNotUnique
        render_error("A draft already exists for this key or invoice", :conflict)
      end

      def update
        operation = -> do
          draft.reload
          return render_error("Invoice is finalized or exporting", :conflict) if draft.invoice&.editing_blocked?
          draft.lock_version = params.require(:lock_version)
          draft.update!(data: draft_data)
        end
        draft.invoice ? draft.invoice.with_lock(&operation) : operation.call
        render json: draft
      end

      def destroy
        draft.destroy!
        head :no_content
      end

      def preview
        record = draft.invoice || draft.season.invoices.new
        numbering = InvoiceNumbering.new(record)
        assign_data(record) unless record.persisted?
        return render_error(record.errors.full_messages, :unprocessable_entity) if !record.persisted? && !numbering.prepare
        operation = -> do
          draft.with_lock do
            raise ActiveRecord::StaleObjectError.new(draft, "preview") unless draft.lock_version == Integer(params.require(:lock_version))
            return render_error("Invoice is finalized or exporting", :conflict) if record.editing_blocked?
            assign_data(record) if record.persisted?
            return render_error(record.errors.full_messages, :unprocessable_entity) unless numbering.save
            draft.update!(invoice: record, data: {})
          end
        end
        record.persisted? ? record.with_lock(&operation) : operation.call
        render json: invoice_json(record)
      end

      private

      def draft = @draft ||= @api_key.user.invoice_drafts.find(params[:id])
      def draft_data
        params.require(:data).permit(*InvoiceDraft::FIELDS, contacts: InvoiceContacts::FIELDS, game_ids: [], line_items_attributes: %i[id key description quantity rate position amount_only _destroy]).to_h
      end
      def assign_data(record)
        return if draft.data.blank?
        attrs = draft.invoice_data.except("line_items_attributes")
        attrs["line_items_attributes"] = Array(draft.data["line_items_attributes"]).map { |item| item.except("key") }
        record.assign_attributes(attrs)
      end
    end
  end
end
