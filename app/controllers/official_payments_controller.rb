class OfficialPaymentsController < ApplicationController
  before_action :need_season
  before_action :no_store
  before_action :load_payment, only: %i[edit update preview pdf odt google_doc]

  def index
    payments = payments_in_register_order.to_a
    last_import = current_season.official_payment_imports.order(id: :desc).first
    connections = HorizonConnection.order(:id).select(:id, :organization_name)
    summaries = payments.map { |payment| payment_summary(payment) }
    horizon_configured = Horizon::Client.configured?
    render inertia: "official_payments/Index", props: {
      year: current_season.year,
      payments: summaries,
      totals: { net_cents: summaries.sum { |payment| payment.fetch(:net_cents) }, needs_review: payments.count { |payment| !payment.reviewed_at }, deposited: payments.count { |payment| payment.deposited_on } },
      last_import: last_import&.props,
      connections: connections.as_json,
      google_connected: google_connected?,
      horizon_configured: horizon_configured,
      can_import: horizon_configured && connections.any? && current_season.year <= Date.current.year
    }
  end

  def create
    payment = current_season.official_payments.create!(params.expect(official_payment: [ :official_name ]))
    redirect_to edit_official_payment_path(payment), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to official_payments_path, status: :see_other, inertia: { errors: error.record.errors }
  rescue ActiveRecord::RecordNotUnique
    redirect_to official_payments_path, status: :see_other, alert: "This official already has a manual entry."
  end

  def edit
    render inertia: "official_payments/Edit", props: {
      payment: payment_summary(@payment).merge(
        @payment.as_json(only: %i[lock_version cheque_delivery assignments visible_note]),
        private_note: @payment.private_note_for(Current.user),
        imported_game_fees_cents: @payment.imported_game_fees_cents,
        imported_travel_ot_cents: @payment.imported_travel_ot_cents,
        horizon_deductions_cents: @payment.horizon_deductions_cents,
        amounts: OfficialPayment::AMOUNTS.index_with { |field| @payment.public_send("#{field}_cents") }
      ),
      year: @payment.season.year,
      google_connected: google_connected?
    }
  end

  def update
    fields = %i[lock_version reviewed visible_note private_note] + OfficialPayment::AMOUNTS + OfficialPayment::CHEQUE_FIELDS
    values = params.expect(official_payment: fields + [ { adjustments: [ %i[label amount] ] } ]).to_h.deep_symbolize_keys
    version = values.delete(:lock_version)
    values[:reviewed] = ActiveModel::Type::Boolean.new.cast(values[:reviewed]) if values.key?(:reviewed)
    values[:deposited_on] = Date.iso8601(values[:deposited_on].to_s) if values[:deposited_on].present?
    @payment.update_from_form!(values, user: Current.user, lock_version: version)
    redirect_to edit_official_payment_path(@payment), status: :see_other, notice: "Official payment saved."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to edit_official_payment_path(@payment), status: :see_other, inertia: { errors: error.record.errors }
  rescue Date::Error
    redirect_to edit_official_payment_path(@payment), status: :see_other, inertia: { errors: { deposited_on: "must be a valid date" } }
  rescue ActiveRecord::StaleObjectError
    redirect_to edit_official_payment_path(@payment), status: :see_other, alert: "This payment changed while it was open. Review the updated amounts and save again."
  rescue ActiveRecord::RecordNotUnique
    redirect_to edit_official_payment_path(@payment), status: :see_other, inertia: { errors: { cheque_number: "is already recorded for this year" } }
  end

  def bulk_edit
    render inertia: "official_payments/BulkEdit", props: {
      year: current_season.year,
      fields: OfficialPayment::REGISTER_FIELDS.map { |field, label| { key: field, label: label } },
      payments: payments_in_register_order.map do |payment|
        register_row(payment).merge(amounts: OfficialPayment::REGISTER_FIELDS.keys.index_with { |field| payment.public_send("#{field}_cents") })
      end
    }
  end

  def bulk_update
    rows = params.expect(payments: [ [ :id, :lock_version, { amounts: OfficialPayment::REGISTER_FIELDS.keys } ] ])
    save_register(rows, bulk_edit_official_payments_path) do |payment, row|
      payment.assign_amounts(row.fetch(:amounts, {}).to_h.symbolize_keys)
    end
  end

  def adjustments
    render inertia: "official_payments/Adjustments", props: {
      year: current_season.year,
      payments: payments_in_register_order.map { |payment| register_row(payment).merge(adjustments: payment.adjustments) }
    }
  end

  def update_adjustments
    rows = params.expect(payments: [ [ :id, :lock_version, { items: [ %i[label amount] ] } ] ])
    save_register(rows, adjustments_official_payments_path) do |payment, row|
      items = row.to_h.deep_symbolize_keys.fetch(:items) { raise ActionController::BadRequest, "Missing adjustment rows" }
      payment.assign_adjustments(items)
    end
  end

  def cheque_sequence
    render inertia: "official_payments/ChequeSequence", props: { year: current_season.year, preview: nil, preview_error: nil }
  end

  def preview_cheque_sequence
    preview = OfficialChequeSequence.new(current_season).preview(params[:first_cheque_number])
    render inertia: "official_payments/ChequeSequence", props: { year: current_season.year, preview: preview, preview_error: nil }
  rescue ArgumentError => error
    render inertia: "official_payments/ChequeSequence", props: { year: current_season.year, preview: nil, preview_error: error.message }
  end

  def record_cheque_sequence
    count = OfficialChequeSequence.new(current_season).record!(params[:preview_token])
    redirect_to official_payments_path, status: :see_other, notice: "Assigned #{helpers.pluralize(count, 'cheque number')}."
  rescue OfficialChequeSequence::Changed, ActiveRecord::RecordInvalid, ArgumentError => error
    redirect_to cheque_sequence_official_payments_path, status: :see_other, alert: error.message
  end

  def statements_pdf
    bytes, filename = OfficialPaymentStatement.packet(current_season)
    send_data bytes, filename: filename, type: "application/pdf"
  rescue ArgumentError => error
    redirect_to official_payments_path, alert: error.message
  end

  def export_sheet
    spreadsheet_id = OfficialEarningsSheet.new(current_season).export!
    inertia_location "https://docs.google.com/spreadsheets/d/#{ERB::Util.url_encode(spreadsheet_id)}/edit"
  rescue GoogleApi::Error, GoogleApi::TransientError => error
    redirect_to official_payments_path, status: :see_other, alert: error.message
  end

  def import
    unless Horizon::Client.configured?
      return redirect_to official_payments_path, status: :see_other, alert: "This InvoiceMe deployment is missing its Horizon credentials."
    end

    connection = HorizonConnection.find_by(id: params[:horizon_connection_id])
    unless connection
      return redirect_to official_payments_path, status: :see_other, alert: "Connect Horizon in Year & settings first."
    end
    year = current_season.year
    return redirect_to official_payments_path, status: :see_other, alert: "The selected year has not started." if year > Date.current.year

    OfficialPaymentImport.start!(current_season, connection)
    redirect_to official_payments_path, status: :see_other
  rescue ActiveRecord::RecordNotUnique
    redirect_to official_payments_path, status: :see_other, alert: "An officials payments import is already running."
  rescue ActiveJob::EnqueueError
    redirect_to official_payments_path, status: :see_other
  end

  def pdf
    return head :conflict unless @payment.reviewed_at

    statement = OfficialPaymentStatement.new(@payment)
    send_data statement.pdf, filename: "#{statement.filename}.pdf", type: "application/pdf"
  end

  def preview
    statement = OfficialPaymentStatement.new(@payment)
    send_data statement.pdf, filename: "#{statement.filename}-preview.pdf", type: "application/pdf", disposition: "inline"
  end

  def odt
    return head :conflict unless @payment.reviewed_at

    statement = OfficialPaymentStatement.new(@payment)
    send_data statement.odt, filename: "#{statement.filename}.odt", type: OdtDocument::MIME
  end

  def google_doc
    doc_id = OfficialPaymentStatement.new(@payment).export_to_google!
    inertia_location "https://docs.google.com/document/d/#{ERB::Util.url_encode(doc_id)}/edit"
  rescue GoogleApi::Error => error
    redirect_to edit_official_payment_path(@payment), status: :see_other, alert: error.message
  end

  private

  def payments_in_register_order = current_season.official_payments.in_payment_order

  def register_row(payment)
    { id: payment.id, name: payment.official_name, payment_number: payment.payment_number, lock_version: payment.lock_version, locked: payment.cheque_recorded? }
  end

  def save_register(rows, location)
    changed = OfficialPayment.update_register!(current_season.official_payments, rows) { |payment, row| yield payment, row }
    redirect_to location, status: :see_other, notice: "Updated #{helpers.pluralize(changed.size, 'official')}."
  rescue ActiveRecord::RecordInvalid => error
    errors = { base: "#{error.record.official_name}: #{error.record.errors.full_messages.to_sentence}" }
    redirect_to location, status: :see_other, inertia: { errors: errors }
  rescue ActiveRecord::StaleObjectError
    redirect_to location, status: :see_other, inertia: { errors: { base: "A payment changed or a cheque was recorded. Open the latest register before reapplying your edits." } }
  end

  def load_payment
    @payment = current_season.official_payments.find(params[:id])
  end

  def google_connected? = GoogleApi.configured? && GoogleConnection.exists?

  def payment_summary(payment)
    payment.as_json(only: %i[id official_name horizon_user_id cheque_number deposited_on payment_number adjustments])
      .merge(payment.register_amounts, status: payment.status)
  end
end
