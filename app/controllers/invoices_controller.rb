class InvoicesController < ApplicationController
  before_action :need_season
  before_action :set_invoice, only: %i[show edit update destroy publish payment notes]
  def index
    @invoices = current_season.invoices.includes(:line_items, :payments).order(issued_on: :desc, id: :desc)
    @all_invoices = @invoices.to_a
    @invoices = @invoices.where("number LIKE :q OR recipient LIKE :q OR description LIKE :q", q: "%#{Invoice.sanitize_sql_like(params[:q].to_s)}%") if params[:q].present?
  end
  def new
    @invoice = current_season.invoices.new(number: "#{current_season.year}_", issued_on: Date.current)
    @invoice.line_items.build(quantity: 1)
    load_games
  end
  def create
    @invoice = current_season.invoices.new(invoice_params)
    if @invoice.save
      redirect_to @invoice, notice: "Draft saved. Preview it before publishing."
    else
      load_games
      render :new, status: :unprocessable_entity
    end
  end
  def show
    respond_to do |format|
      format.html
      format.pdf { send_data InvoiceDocument.new(@invoice).pdf, filename: "#{@invoice.number}.pdf", type: "application/pdf", disposition: "inline" }
    end
  end
  def edit
    return redirect_to @invoice, alert: "This invoice is finalized" if @invoice.finalized_at
    load_games
  end
  def update
    saved = @invoice.with_lock do
      if @invoice.finalized_at
        @invoice.errors.add(:base, "This invoice is finalized")
        false
      else
        @invoice.update(invoice_params)
      end
    end
    if saved
      redirect_to @invoice, notice: "Draft updated"
    else
      load_games
      render :edit, status: :unprocessable_entity
    end
  end
  def destroy
    if @invoice.finalized_at
      redirect_to @invoice, alert: "Finalized invoices are retained for your records"
    else
      @invoice.destroy!
      redirect_to root_path, notice: "Draft deleted"
    end
  end
  def publish
    PublishInvoice.new(@invoice).call
    redirect_to @invoice, notice: "Saved to Google Drive and recorded in the master spreadsheet"
  end
  def payment
    @invoice.with_lock do
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
    @invoice = Invoice.find(params[:id])
    @current_season = @invoice.season
    session[:season_id] = @current_season.id
  end
  def load_games = @games = current_season.games.includes(:invoices).order(date: :desc)
  def invoice_params
    attrs = params.require(:invoice).permit(:number, :recipient, :contact, :recipient_address, :description, :issued_on, :due_on, :public_notes, :private_notes, game_ids: [], line_items_attributes: %i[id description quantity rate position _destroy])
    if attrs[:game_ids]
      ids = attrs[:game_ids].reject(&:blank?)
      raise ActiveRecord::RecordNotFound unless current_season.games.where(id: ids).count == ids.uniq.size
    end
    attrs
  end
end
