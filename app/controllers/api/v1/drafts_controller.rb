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
        save = -> do
          record.invoice_group = record.invoice&.invoice_group
          record.data = draft_data(record)
          record.save!
        end
        record.invoice ? record.invoice.with_lock(&save) : save.call
        render json: record, status: :created
      rescue ActiveRecord::RecordNotUnique
        render_error("A draft already exists for this key or invoice", :conflict)
      end

      def update
        operation = -> do
          draft.reload
          return render_error("Invoice is finalized or exporting", :conflict) if draft.invoice&.editing_blocked?
          draft.lock_version = params.require(:lock_version)
          draft.update!(data: draft_data(draft))
        end
        draft.invoice ? draft.invoice.with_lock(&operation) : operation.call
        render json: draft
      end

      def destroy
        draft.destroy!
        head :no_content
      end

      def preview
        group = draft.invoice_group unless draft.invoice_id
        record = draft.invoice || draft.season.invoices.new
        record.assign_attributes(invoice_group: group, game_ids: group.game_ids) if group
        numbering = InvoiceNumbering.new(record)
        assign_data(record) unless record.persisted?
        return render_error(record.errors.full_messages, :unprocessable_entity) if !record.persisted? && !numbering.prepare
        operation = -> do
          draft.with_lock do
            raise ActiveRecord::StaleObjectError.new(draft, "preview") unless draft.lock_version == Integer(params.require(:lock_version))
            return render_error("Invoice is finalized or exporting", :conflict) if record.editing_blocked?
            assign_data(record) if record.persisted?
            return render_error(record.errors.full_messages, :unprocessable_entity) unless numbering.save
            PrivateBreakdownPersistence.save!(user: @api_key.user, invoice: record, data: draft.data)
            draft.update!(invoice: record, data: {})
          end
        end
        if record.persisted?
          record.with_lock(&operation)
        elsif group
          group.with_lock do
            record.game_ids = group.game_ids
            operation.call
          end
        else
          operation.call
        end
        render json: invoice_json(record)
      end

      private

      def draft = @draft ||= @api_key.user.invoice_drafts.find(params[:id])
      def draft_data(record)
        data = params.require(:data).permit(*InvoiceDraft::FIELDS, contacts: InvoiceContacts::FIELDS, game_ids: [], line_items_attributes: [ :id, :key, :description, :quantity, :rate, :position, :amount_only, :_destroy, { private_breakdown: [ :notes, { entries: %i[key description amount] } ] } ]).to_h
        if record.invoice_group && data.key?("game_ids")
          submitted = data.delete("game_ids").map(&:to_s).uniq.sort
          if submitted != record.invoice_group.game_ids.map(&:to_s).sort
            record.errors.add(:games, "must match the shared game selection")
            raise ActiveRecord::RecordInvalid.new(record)
          end
        end
        data
      end
      def assign_data(record)
        return if draft.data.blank?
        attrs = draft.invoice_data.except("line_items_attributes")
        attrs["line_items_attributes"] = Array(draft.data["line_items_attributes"]).map.with_index do |item, index|
          line_attrs = item.except("key", "private_breakdown")
          line_attrs["position"] = index if item.key?("private_breakdown") && !line_attrs.key?("position")
          line_attrs
        end
        record.assign_attributes(attrs)
      end
    end
  end
end
