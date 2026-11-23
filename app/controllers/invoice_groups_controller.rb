class InvoiceGroupsController < ApplicationController
  before_action :need_season
  before_action :set_group, only: %i[show update add_existing attach_invoice]

  def index
    page = WorkspacePage.new(current_season.invoice_groups.order(updated_at: :desc, id: :desc), params[:page], params[:per_page])
    render inertia: "invoice_groups/Index", props: {
      groups: -> {
        groups = page.records.to_a
        game_counts = InvoiceGroupGame.where(invoice_group: groups).group(:invoice_group_id).count
        invoice_counts = Invoice.where(invoice_group: groups).group(:invoice_group_id).count
        draft_counts = open_workbenches.where(invoice_group: groups, invoice_id: nil).reorder(nil).group(:invoice_group_id).count
        groups.map do |group|
          group.as_json(only: %i[id name]).merge(
            game_count: game_counts.fetch(group.id, 0), invoice_count: invoice_counts.fetch(group.id, 0), draft_count: draft_counts.fetch(group.id, 0)
          )
        end
      },
      pagination: page.props
    }
  end

  def show
    render inertia: "invoice_groups/Show", props: game_picker_props.merge(
      group: -> { @group.as_json(only: %i[id name lock_version]).merge(game_ids: @group.game_ids, games_locked: @group.games_locked?) },
      entries: -> { invoice_group_entries(@group) },
      selected_games: -> { game_list_props(@group.games) }
    )
  end

  def create
    draft = Current.user.invoice_drafts.find(params[:draft_id]) if params[:draft_id].present?
    invoice = draft ? draft.invoice : Invoice.find_by(id: params[:invoice_id])
    raise ActiveRecord::RecordNotFound if params[:invoice_id].present? && !invoice

    group = if draft
      InvoiceGroup.for_workbench!(draft)
    elsif invoice
      InvoiceGroup.for_invoice!(invoice)
    else
      InvoiceGroup.start!(season: current_season, game_ids: params.permit(game_ids: [])[:game_ids])
    end
    redirect_to group, notice: "Invoice group ready. Add an invoice for each payer."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to group_creation_origin(draft, invoice), alert: e.record.errors.full_messages.to_sentence
  rescue ActiveRecord::StaleObjectError
    redirect_to group_creation_origin(draft, invoice), alert: "This workbench changed. Review it before creating the group."
  end

  def update
    attrs = params.permit(:name, :lock_version, game_ids: [])
    @group.update_selection!(name: attrs[:name], game_ids: attrs[:game_ids], revision: attrs[:lock_version])
    redirect_to @group, notice: "Invoice group updated"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @group, inertia: { errors: e.record.errors }
  rescue ActiveRecord::StaleObjectError
    redirect_to @group, alert: "This group changed elsewhere. Review its current selection before editing again."
  end

  def add_existing
    invoice = @group.season.invoices.find(params[:invoice_id]) if params[:invoice_id].present?
    if invoice
      render inertia: "invoice_groups/AddExisting", props: {
        group: @group.as_json(only: %i[id name]),
        review: -> { attachment_review(invoice) }
      }
    else
      query = params[:q].to_s.strip.first(120)
      scope = @group.season.invoices.where(invoice_group_id: nil).order(issued_on: :desc, id: :desc)
      if query.present?
        scope = scope.where("number LIKE :q OR recipient LIKE :q OR description LIKE :q", q: "%#{Invoice.sanitize_sql_like(query)}%")
      end
      page = WorkspacePage.new(scope, params[:page], params[:per_page])
      render inertia: "invoice_groups/AddExisting", props: {
        group: @group.as_json(only: %i[id name]), review: nil, query: query, pagination: page.props,
        invoices: -> { page.records.includes(:line_items, :payments).map { |record| invoice_props(record) } }
      }
    end
  end

  def attach_invoice
    invoice = @group.season.invoices.find(params.require(:invoice_id))
    @group.attach_invoice!(invoice, review_token: params[:review_token])
    redirect_to @group, notice: "Invoice added to the group"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to add_existing_invoice_group_path(@group, invoice_id: invoice.id), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def attachment_review(invoice)
    review = @group.attachment_review(invoice)
    review.merge(
      invoice: invoice_props(invoice),
      games_added: game_references(review.fetch(:games_added)),
      games_removed: game_references(review.fetch(:games_removed))
    )
  end

  def game_references(ids)
    @group.season.games.where(id: ids).order(:date, :external_id, :id).select(:id, :external_id, :date, :home_team, :away_team).map do |game|
      { id: game.id, external_id: game.external_id, date: game.date, matchup: game.matchup }
    end
  end

  def set_group
    @group = InvoiceGroup.find(params[:id])
    @current_season = @group.season
    session[:season_id] = @group.season_id
  end

  def group_creation_origin(draft, invoice)
    return edit_invoice_draft_path(draft) if draft
    return invoice_path(invoice) if invoice

    games_path
  end
end
