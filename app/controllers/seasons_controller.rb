class SeasonsController < ApplicationController
  def new
    previous = Season.order(year: :desc).first
    year = previous ? previous.year + 1 : Date.current.year
    @season = Season.new(year: year, issuer: previous&.issuer || Season::DEFAULT_ISSUER, sheet_name: "#{year} invoices")
    render_settings
  end
  def create
    @season = Season.new(season_params)
    if @season.save
      session[:season_id] = @season.id
      redirect_to edit_season_path(@season), notice: "Invoice year created"
    else
      redirect_to new_season_path, inertia: { errors: @season.errors }
    end
  end
  def edit
    @season = Season.find(params[:id])
    render_settings
  end
  def preview
    season = Season.find(params[:id])
    invoice = season.invoices.new(number: "#{season.year}_PREVIEW", recipient: "Example organization", contact: "Example contact", description: "Invoice design preview", issued_on: Date.current)
    invoice.line_items.build(description: "Officials", quantity: 4, rate: "1000")
    invoice.line_items.build(description: "Assigning", quantity: 1, rate: "100")
    send_data InvoiceDocument.new(invoice).pdf, filename: "invoice-style-preview.pdf", type: "application/pdf", disposition: "inline"
  end
  def update
    @season = Season.find(params[:id])
    if @season.update(season_params)
      redirect_to edit_season_path(@season), notice: "Settings saved. Finalized invoices keep their original details."
    else
      redirect_to edit_season_path(@season), inertia: { errors: @season.errors }
    end
  end
  def select
    session[:season_id] = Season.find(params[:id]).id
    destination = case params[:section]
    when "expenses" then expenses_path
    when "games" then games_path
    when "official_payments" then official_payments_path
    when "invoice_drafts" then invoice_drafts_path
    when "invoice_groups" then invoice_groups_path
    when "contacts" then contacts_path
    when "seasons" then edit_season_path(session[:season_id])
    else root_path
    end
    redirect_to destination
  end
  private
  def render_settings
    render inertia: "seasons/Edit", props: { season: @season.as_json(only: %i[id year issuer drive_folder_id pdf_folder_id financials_folder_id spreadsheet_id sheet_name ledger_start_row]), google: { configured: GoogleApi.configured?, email: GoogleConnection.first&.email }, horizon: { configured: Horizon::Client.configured?, connections: HorizonConnection.order(:id).map { |connection| { id: connection.id, organization_name: connection.organization_name } } } }
  end
  def season_params
    params.require(:season).permit(:year, :drive_folder_id, :pdf_folder_id, :financials_folder_id, :spreadsheet_id, :sheet_name, :ledger_start_row, issuer: %i[name payable_to treasurer email address payment_instructions])
  end
end
