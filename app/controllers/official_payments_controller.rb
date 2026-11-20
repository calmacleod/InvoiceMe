class OfficialPaymentsController < ApplicationController
  before_action :need_season
  before_action :no_store
  before_action :load_payment, only: %i[edit update pdf odt google_doc]

  def index
    payments = current_season.official_payments.order(:official_name, :id).to_a
    last_import = current_season.official_payment_imports.order(id: :desc).first
    connections = HorizonConnection.order(:id).select(:id, :organization_name)
    render inertia: "official_payments/Index", props: {
      year: current_season.year,
      payments: payments.map { |payment| payment_summary(payment) },
      totals: { net_cents: payments.sum(&:net_cents), needs_review: payments.count { |payment| !payment.reviewed_at }, deposited: payments.count { |payment| payment.deposited_on } },
      last_import: last_import&.props,
      connections: connections.as_json,
      can_import: Horizon::Client.configured? && connections.any? && current_season.year <= Date.current.year
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
        @payment.as_json(only: %i[lock_version cheque_delivery assignments]),
        imported_game_fees_cents: @payment.imported_game_fees_cents,
        imported_travel_ot_cents: @payment.imported_travel_ot_cents,
        horizon_deductions_cents: @payment.horizon_deductions_cents,
        amounts: OfficialPayment::AMOUNTS.index_with { |field| @payment.public_send("#{field}_cents") }
      ),
      year: @payment.season.year,
      google_connected: GoogleApi.configured? && GoogleConnection.exists?
    }
  end

  def update
    values = params.expect(official_payment: %i[lock_version reviewed] + OfficialPayment::AMOUNTS + OfficialPayment::CHEQUE_FIELDS).to_h.symbolize_keys
    raise ActiveRecord::StaleObjectError.new(@payment, "update") unless values.delete(:lock_version).to_s == @payment.lock_version.to_s

    values[:reviewed] = ActiveModel::Type::Boolean.new.cast(values[:reviewed])
    values[:deposited_on] = Date.iso8601(values[:deposited_on].to_s) if values[:deposited_on].present?
    @payment.update_from_form!(values)
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

  def import
    connection = HorizonConnection.find_by(id: params[:horizon_connection_id])
    unless connection && Horizon::Client.configured?
      return redirect_to official_payments_path, status: :see_other, alert: "Connect Horizon in Year & settings first."
    end
    year = current_season.year
    return redirect_to official_payments_path, status: :see_other, alert: "The selected year has not started." if year > Date.current.year

    through = [ Date.current, Date.new(year, 12, 31) ].min
    OfficialPaymentImport.expire_stalled!
    import_record = current_season.official_payment_imports.create!
    job = OfficialPaymentImportJob.perform_later(import_record.id, connection.id, through.iso8601)
    raise ActiveJob::EnqueueError unless job&.successfully_enqueued?

    redirect_to official_payments_path, status: :see_other
  rescue ActiveRecord::RecordNotUnique
    redirect_to official_payments_path, status: :see_other, alert: "An officials payments import is already running."
  rescue ActiveJob::EnqueueError
    import_record&.update!(status: "failed", error: "The import could not be queued.")
    redirect_to official_payments_path, status: :see_other
  end

  def pdf
    return head :conflict unless @payment.reviewed_at

    statement = OfficialPaymentStatement.new(@payment)
    send_data statement.pdf, filename: "#{statement.filename}.pdf", type: "application/pdf"
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

  def load_payment
    @payment = current_season.official_payments.find(params[:id])
  end

  def payment_summary(payment)
    payment.as_json(only: %i[id official_name horizon_user_id cheque_number deposited_on]).merge(
      status: payment.status, game_fees_cents: payment.game_fees_cents, travel_ot_cents: payment.travel_ot_cents,
      association_fee_cents: payment.association_fee_cents, net_cents: payment.net_cents
    )
  end
end
