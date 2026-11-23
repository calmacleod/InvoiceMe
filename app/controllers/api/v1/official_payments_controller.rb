module Api
  module V1
    class OfficialPaymentsController < BaseController
      before_action :prevent_caching
      before_action :load_payment, only: %i[show update preview pdf odt google_doc]
      rescue_from ActiveRecord::StaleObjectError, with: -> { render_error("A payment changed or a cheque was recorded. Reload the register and retry.", :conflict) }
      rescue_from ActiveRecord::RecordNotUnique, with: -> { render_error("An official payment or cheque number was recorded concurrently. Reload the register and retry.", :conflict) }

      def index
        render json: paginate(season.official_payments.order(:payment_number)) { |payment| payment_summary(payment) }
      end

      def totals
        render json: { season_id: season.id, totals: OfficialPayment.register_totals(season.official_payments.find_each) }
      end

      def show
        render json: payment_details(@payment)
      end

      def create
        payment = season.official_payments.create!(params.expect(official_payment: [ :official_name ]))
        render json: payment_details(payment), status: :created
      end

      def update
        fields = %i[lock_version reviewed] + OfficialPayment::AMOUNTS + OfficialPayment::CHEQUE_FIELDS
        values = params.expect(official_payment: fields + [ { adjustments: [ %i[label amount] ] } ]).to_h.deep_symbolize_keys
        version = values.delete(:lock_version)
        raise ArgumentError, "A lock_version and at least one payment field are required" if version.nil? || values.empty?
        raise ActiveRecord::StaleObjectError.new(@payment, "update") unless version.to_s == @payment.lock_version.to_s

        if values.key?(:reviewed) && ![ true, false ].include?(values[:reviewed])
          raise ArgumentError, "reviewed must be a boolean"
        end
        if values.key?(:deposited_on)
          values[:deposited_on] = values[:deposited_on].presence&.then { |date| Date.iso8601(date.to_s) }
        end
        @payment.update_from_form!(values)
        render json: payment_details(@payment)
      end

      def bulk_update
        rows = params.expect(payments: [ [ :id, :lock_version, { amounts: OfficialPayment::REGISTER_FIELDS.keys, adjustments: [ %i[label amount] ] } ] ])
        rows.each do |row|
          unless row[:id].to_s.match?(/\A[1-9]\d*\z/) && row[:lock_version].to_s.match?(/\A\d+\z/) &&
              (row[:amounts].present? || row.key?(:adjustments))
            raise ArgumentError, "Each row requires an id, lock_version, and amounts or adjustments"
          end
        end

        changed = OfficialPayment.update_register!(season.official_payments, rows) do |payment, row|
          payment.assign_amounts(row[:amounts].to_h.symbolize_keys) if row[:amounts].present?
          payment.assign_adjustments(row[:adjustments].map { |item| item.to_h.symbolize_keys }) if row.key?(:adjustments)
        end
        render json: { updated: changed.size, data: changed.map { |payment| payment_summary(payment) } }
      end

      def imports
        records = season.official_payment_imports.order(id: :desc)
        connections = HorizonConnection.order(:id).select(:id, :organization_name)
        render json: paginate(records) { |record| import_json(record) }.merge(
          connections: connections.as_json, can_import: Horizon::Client.configured? && connections.any? && season.year <= Date.current.year
        )
      end

      def show_import
        render json: import_json(season.official_payment_imports.find(params[:import_id]))
      end

      def start_import
        raise ArgumentError, "The selected year has not started" if season.year > Date.current.year
        raise ArgumentError, "Configure Horizon in Year & settings first" unless Horizon::Client.configured?

        connection = HorizonConnection.find(params.require(:horizon_connection_id))
        render json: import_json(OfficialPaymentImport.start!(season, connection)), status: :accepted
      rescue ActiveRecord::RecordNotUnique
        render_error("An officials payments import is already running", :conflict)
      rescue ActiveJob::EnqueueError
        render_error("The import could not be queued", :service_unavailable)
      end

      def preview
        statement = OfficialPaymentStatement.new(@payment)
        send_data statement.pdf, filename: "#{statement.filename}-preview.pdf", type: "application/pdf", disposition: "inline"
      end

      def pdf
        return render_error("Review the payment before downloading the statement", :conflict) unless @payment.reviewed_at

        statement = OfficialPaymentStatement.new(@payment)
        send_data statement.pdf, filename: "#{statement.filename}.pdf", type: "application/pdf"
      end

      def odt
        return render_error("Review the payment before downloading the statement", :conflict) unless @payment.reviewed_at

        statement = OfficialPaymentStatement.new(@payment)
        send_data statement.odt, filename: "#{statement.filename}.odt", type: OdtDocument::MIME
      end

      def google_doc
        id = OfficialPaymentStatement.new(@payment).export_to_google!
        render json: { id: id, url: "https://docs.google.com/document/d/#{ERB::Util.url_encode(id)}/edit" }
      end

      def export_sheet
        id = OfficialEarningsSheet.new(season).export!
        render json: { id: id, url: "https://docs.google.com/spreadsheets/d/#{ERB::Util.url_encode(id)}/edit" }, status: :created
      end

      private

      def prevent_caching = response.headers["Cache-Control"] = "no-store"
      def season = @season ||= Season.find(params.require(:season_id))
      def load_payment = @payment = OfficialPayment.find(params[:id])

      def import_json(record)
        record.props.merge(id: record.id, season_id: record.season_id, horizon_connection_id: record.horizon_connection_id)
      end

      def payment_summary(payment)
        payment.as_json(only: %i[id season_id payment_number official_name horizon_user_id lock_version reviewed_at cheque_number deposited_on cheque_delivery adjustments])
          .merge(payment.register_amounts, status: payment.status)
      end

      def payment_details(payment)
        payment_summary(payment).merge(assignments: payment.assignments, imported_game_fees_cents: payment.imported_game_fees_cents,
          imported_travel_ot_cents: payment.imported_travel_ot_cents, horizon_deductions_cents: payment.horizon_deductions_cents)
      end
    end
  end
end
