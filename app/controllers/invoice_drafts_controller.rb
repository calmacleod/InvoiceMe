class InvoiceDraftsController < ApplicationController
  before_action :need_season
  before_action :set_draft, only: %i[edit update preview destroy]
  rescue_from ActiveRecord::StaleObjectError, with: :conflict

  def index
    scope = own_drafts.where(season: current_season).open_work
    scope = scope.where("invoice_drafts.title LIKE ?", "%#{InvoiceDraft.sanitize_sql_like(params[:q].to_s)}%") if params[:q].present?
    page = WorkspacePage.new(scope, params[:page], params[:per_page])
    render inertia: "drafts/Index", props: { drafts: -> { page.records.summaries.map(&:metadata) }, pagination: page.props, query: params[:q].to_s }
  end

  def create
    if request.format.json?
      season = Season.find(params[:season_id])
      @draft = own_drafts.find_or_initialize_by(client_key: params.require(:client_key))
      raise ActiveRecord::RecordNotFound if @draft.persisted? && @draft.season_id != season.id
      @draft.season = season
      if params[:invoice_id].present?
        invoice = season.invoices.find(params[:invoice_id])
        raise ActiveRecord::RecordNotFound if @draft.persisted? && @draft.invoice_id != invoice.id
        existing = own_drafts.find_by(invoice: invoice)
        return render(json: { error: "This invoice already has a workbench. Open it from Draft workbench." }, status: :conflict) if existing && existing != @draft
        @draft.invoice = invoice
      end
      save_data
    else
      if params[:invoice_id].present?
        invoice = Invoice.find(params[:invoice_id])
        invoice.with_lock do
          return redirect_to invoice, alert: "This invoice is finalized or exporting" if invoice.editing_blocked?
          draft = own_drafts.find_or_create_by!(invoice: invoice) { |work| work.season = invoice.season; work.client_key = SecureRandom.uuid }
          redirect_to edit_invoice_draft_path(draft)
        end
      else
        draft = own_drafts.create!(season: current_season, client_key: SecureRandom.uuid)
        redirect_to edit_invoice_draft_path(draft)
      end
    end
  end

  def edit
    return redirect_to @draft.invoice, alert: "This invoice is finalized or exporting" if @draft.invoice&.editing_blocked?
    @current_season = @draft.season
    session[:season_id] = @draft.season_id
    render_invoice_editor(@draft.invoice || fresh_invoice, draft: @draft)
  end

  def update
    save_data
  end

  def preview
    invoice = @draft.invoice || @draft.season.invoices.new
    invoice.persisted? ? invoice.with_lock { preview_locked(invoice) } : preview_locked(invoice)
  end

  def destroy
    @draft.destroy!
    redirect_to invoice_drafts_path, notice: "Workbench draft deleted"
  end

  private
  def preview_locked(invoice)
    @draft.with_lock do
      raise ActiveRecord::StaleObjectError.new(@draft, "preview") unless @draft.lock_version == params.require(:lock_version).to_i
      return redirect_to invoice, alert: "This invoice is finalized or exporting" if invoice.editing_blocked?
      if @draft.data.present?
        attrs = @draft.invoice_data.except("line_items_attributes")
        attrs["line_items_attributes"] = Array(@draft.data["line_items_attributes"]).map { |item| item.except("key") }
        invoice.assign_attributes(attrs)
      end
      if invoice.save
        @draft.update!(invoice: invoice, data: {})
        redirect_to invoice, notice: "Draft saved. Preview it before publishing."
      else
        redirect_to edit_invoice_draft_path(@draft), inertia: { errors: invoice.errors }
      end
    end
  end

  def own_drafts = InvoiceDraft.where(user: Current.user)
  def set_draft = @draft = own_drafts.find(params[:id])
  def save_data
    @draft.invoice ? @draft.invoice.with_lock { persist_data } : persist_data
  end
  def persist_data
    @draft.reload if @draft.persisted?
    return conflict if @draft.invoice&.editing_blocked?
    data = params.require(:data).permit(*InvoiceDraft::FIELDS, contacts: InvoiceContacts::FIELDS, game_ids: [], line_items_attributes: %i[id key description quantity rate position amount_only _destroy]).to_h
    # Retrying an acknowledged-lost request is harmless. A different payload
    # must carry the current revision; another tab's work is never overwritten.
    if @draft.persisted? && @draft.data == data
      return render json: @draft.metadata
    end
    if @draft.persisted?
      @draft.lock_version = params.require(:lock_version)
    end
    @draft.data = data
    if @draft.save
      render json: @draft.metadata
    else
      render json: { error: @draft.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { error: "A workbench already exists for this invoice. Open it from Draft workbench." }, status: :conflict
  end
  def conflict
    message = "This draft changed in another tab, was finalized, or is being exported. Your edits are still on this page. Open the saved draft in another tab to compare before continuing."
    if request.format.json?
      render json: { error: message }, status: :conflict
    else
      redirect_to edit_invoice_draft_path(@draft), alert: message
    end
  end
end
