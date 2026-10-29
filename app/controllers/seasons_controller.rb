class SeasonsController < ApplicationController
  def new
    previous = Season.order(year: :desc).first
    year = previous ? previous.year + 1 : Date.current.year
    @season = Season.new(year: year, issuer: previous&.issuer || Season::DEFAULT_ISSUER, sheet_name: "#{year} invoices")
  end
  def create
    @season = Season.new(season_params)
    if @season.save
      session[:season_id] = @season.id
      redirect_to edit_season_path(@season), notice: "Invoice year created"
    else
      render :new, status: :unprocessable_entity
    end
  end
  def edit = @season = Season.find(params[:id])
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
      render :edit, status: :unprocessable_entity
    end
  end
  def select
    session[:season_id] = Season.find(params[:id]).id
    redirect_to root_path
  end
  private
  def season_params
    params.require(:season).permit(:year, :drive_folder_id, :pdf_folder_id, :spreadsheet_id, :sheet_name, :ledger_start_row, issuer: %i[name payable_to treasurer email address payment_instructions])
  end
end
