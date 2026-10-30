class InvoicesController < ApplicationController
  before_action :need_season
  before_action :set_invoice, only: %i[show edit update destroy publish payment notes]
  def index
    invoices = current_season.invoices.order(issued_on: :desc, id: :desc)
    invoices = invoices.where("number LIKE :q OR recipient LIKE :q OR description LIKE :q", q: "%#{Invoice.sanitize_sql_like(params[:q].to_s)}%") if params[:q].present?
    page = WorkspacePage.new(invoices, params[:page], params[:per_page])
    render inertia: "invoices/Index", props: {
      invoices: -> { page.records.includes(:line_items, :payments).map { |invoice| invoice_props(invoice) } },
      pagination: page.props, total_count: -> { current_season.invoices.count }, query: params[:q].to_s,
      totals: -> {
        totals = InvoiceTotals.new(current_season.invoices).call
        totals.merge(drafts: totals[:drafts] + open_workbenches.where(invoice_id: nil).count)
      },
      workbenches: -> { open_workbenches.summaries.limit(6).map(&:metadata) }
    }
  end
  def new
    render_invoice_editor(fresh_invoice)
  end
  def create
    @invoice = current_season.invoices.new(invoice_params)
    if @invoice.save
      redirect_to @invoice, notice: "Draft saved. Preview it before publishing."
    else
      redirect_to new_invoice_path, inertia: { errors: @invoice.errors }
    end
  end
  def show
    respond_to do |format|
      format.html do
        render inertia: "invoices/Show", props: {
          invoice: -> { invoice_props(@invoice, detail: true) },
          google_export: -> { @invoice.invoice_exports.order(id: :desc).first&.progress }
        }
      end
      format.pdf { send_data InvoiceDocument.new(@invoice).pdf, filename: "#{@invoice.number}.pdf", type: "application/pdf", disposition: "inline" }
    end
  end
  def edit
    return redirect_to @invoice, alert: "This invoice is finalized or exporting" if @invoice.editing_blocked?
    draft = InvoiceDraft.find_by(user: Current.user, invoice: @invoice)
    return redirect_to edit_invoice_draft_path(draft) if draft
    render_invoice_editor(@invoice)
  end
  def update
    saved = @invoice.with_lock do
      if @invoice.editing_blocked?
        @invoice.errors.add(:base, "This invoice is finalized or exporting")
        false
      else
        @invoice.update(invoice_params)
      end
    end
    if saved
      redirect_to @invoice, notice: "Draft updated"
    else
      redirect_to edit_invoice_path(@invoice), inertia: { errors: @invoice.errors }
    end
  end
  def destroy
    @invoice.with_lock do
      if @invoice.editing_blocked?
        redirect_to @invoice, alert: "Finalized invoices and invoices being exported are retained for your records"
      else
        @invoice.destroy!
        redirect_to root_path, notice: "Draft deleted"
      end
    end
  end
  def publish
    InvoiceExport.enqueue_for(@invoice)
    redirect_to @invoice, notice: "Google export queued. You can follow its progress here or return later."
  end
  def payment
    @invoice.with_lock do
      raise GoogleApi::Error, "Wait for the Google export to finish before recording a payment." if @invoice.exporting?
      @invoice.payments.create!(amount_cents: MoneyValue.cents(params[:amount]), received_on: params[:received_on], method: params[:payment_method], notes: params[:notes])
      @invoice.update!(published_at: nil) if @invoice.google_doc_id
    end
    redirect_to @invoice, notice: "Payment recorded. Use Sync to Google to update the master ledger."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @invoice, alert: e.message
  end
  def notes
    @invoice.update!(private_notes: params[:private_notes])
    redirect_to @invoice, notice: "Private notes saved"
  end
  private
  def set_invoice
    scope = %w[show edit].include?(action_name) ? Invoice.includes(:line_items, :payments) : Invoice.all
    @invoice = scope.find(params[:id])
    @current_season = @invoice.season
    session[:season_id] = @current_season.id
  end
  def invoice_params
    attrs = params.require(:invoice).permit(:number, :recipient, :contact, :recipient_address, :description, :issued_on, :due_on, :public_notes, :private_notes, contacts: InvoiceContacts::FIELDS, game_ids: [], line_items_attributes: %i[id description quantity rate position amount_only _destroy])
    if attrs[:game_ids]
      ids = attrs[:game_ids].reject(&:blank?)
      raise ActiveRecord::RecordNotFound unless current_season.games.where(id: ids).count == ids.uniq.size
    end
    attrs
  end
end
