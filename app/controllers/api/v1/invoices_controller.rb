module Api
  module V1
    class InvoicesController < BaseController
      def index
        scope = Season.find(params.require(:season_id)).invoices.order(issued_on: :desc, id: :desc)
        scope = scope.where("number LIKE :q OR recipient LIKE :q OR description LIKE :q", q: "%#{Invoice.sanitize_sql_like(params[:q])}%") if params[:q].present?
        render json: paginate(scope.includes(:line_items, :payments)) { |invoice| invoice_json(invoice) }
      end

      def show
        render json: invoice_json(invoice)
      end

      def create
        season = Season.find(params.require(:season_id))
        record = season.invoices.new(invoice_params(season))
        record.number_suffix ||= InvoiceNumbering.suffix(record.number, season.year)
        return render_error(record.errors.full_messages, :unprocessable_entity) unless InvoiceNumbering.new(record).save

        render json: invoice_json(record), status: :created
      end

      def update
        invoice.with_lock do
          return render_error("Invoice is finalized or exporting", :conflict) if invoice.editing_blocked?
          invoice.update!(invoice_params(invoice.season))
        end
        render json: invoice_json(invoice)
      end

      def destroy
        invoice.with_lock do
          return render_error("Finalized invoices and invoices being exported are retained", :conflict) if invoice.editing_blocked? || invoice.ever_finalized?
          invoice.destroy!
        end
        head :no_content
      end

      def publish
        export = InvoiceExport.enqueue_for(invoice)
        render json: export.progress, status: :accepted
      end

      def reopen
        invoice.reopen!
        render json: invoice_json(invoice)
      end

      def payment
        invoice.with_lock do
          raise GoogleApi::Error, "Wait for the Google export to finish before recording a payment." if invoice.exporting?
          invoice.payments.create!(amount_cents: MoneyValue.cents(params.require(:amount)), received_on: params[:received_on], method: params[:method], notes: params[:notes])
          invoice.update!(published_at: nil) if invoice.google_doc_id
        end
        render json: invoice_json(invoice), status: :created
      end

      def notes
        invoice.update!(private_notes: params[:private_notes])
        render json: invoice_json(invoice)
      end

      def pdf
        send_data InvoiceDocument.new(invoice).pdf, filename: "#{invoice.number}.pdf", type: "application/pdf", disposition: "inline"
      end

      private

      def invoice = @invoice ||= Invoice.find(params[:id])
      def invoice_params(season)
        attrs = params.require(:invoice).permit(:number, :number_suffix, :recipient, :contact, :recipient_address, :description, :issued_on, :due_on, :public_notes, :private_notes, contacts: InvoiceContacts::FIELDS, game_ids: [], line_items_attributes: %i[id description quantity rate position amount_only _destroy])
        if attrs[:game_ids]
          ids = attrs[:game_ids].reject(&:blank?)
          raise ActiveRecord::RecordNotFound unless season.games.where(id: ids).count == ids.uniq.size
        end
        attrs
      end
    end
  end
end
