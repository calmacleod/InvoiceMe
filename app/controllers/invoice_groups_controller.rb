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

    group = if invoice
      invoice.with_lock { group_invoice(invoice, draft&.id) }
    elsif draft
      draft.with_lock do
        raise ActiveRecord::StaleObjectError.new(draft, "group") if draft.invoice_id

        draft.invoice_group || InvoiceGroup.start!(season: draft.season, game_ids: draft.data["game_ids"]).tap do |new_group|
          draft.update!(invoice_group: new_group, data: draft.data.except("game_ids"))
        end
      end
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
    @group.with_lock do
      invoice.with_lock do
        unless invoice.invoice_group_id == @group.id
          original_ids, shared_ids = invoice.game_ids.sort, @group.game_ids.sort
          blocker = attachment_blocker(invoice, original_ids, shared_ids)
          reject_attachment!(invoice, blocker) if blocker
          token = params[:review_token].to_s.presence
          if (token || original_ids != shared_ids) && attachment_verifier.verified(token.to_s) != [ @group.id, invoice.id, original_ids, shared_ids ]
            reject_attachment!(invoice, "Review the current game changes before adding this invoice")
          end
          verify_workbench_selections!(invoice, [ original_ids, shared_ids ])
          link_invoice!(invoice, @group)
        end
      end
    end
    redirect_to @group, notice: "Invoice added to the group"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to add_existing_invoice_group_path(@group, invoice_id: invoice.id), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def attachment_review(invoice)
    original_ids, shared_ids = invoice.game_ids.sort, @group.game_ids.sort
    {
      invoice: invoice_props(invoice),
      shared_game_count: shared_ids.size,
      games_added: game_references(shared_ids - original_ids),
      games_removed: game_references(original_ids - shared_ids),
      blocked_reason: attachment_blocker(invoice, original_ids, shared_ids),
      token: attachment_verifier.generate([ @group.id, invoice.id, original_ids, shared_ids ], expires_in: 30.minutes)
    }
  end

  def attachment_blocker(invoice, original_ids, shared_ids)
    return "This invoice already belongs to an invoice group." if invoice.invoice_group_id
    return if original_ids == shared_ids
    return "Wait for the current export to finish before updating this invoice’s linked games." if invoice.exporting?
    "This invoice has been finalized. Its existing game links must match the group’s games." if invoice.locked_game_history? && original_ids.any?
  end

  def game_references(ids)
    @group.season.games.where(id: ids).order(:date, :external_id, :id).select(:id, :external_id, :date, :home_team, :away_team).map do |game|
      { id: game.id, external_id: game.external_id, date: game.date, matchup: game.matchup }
    end
  end

  def attachment_verifier = Rails.application.message_verifier(:invoice_group_attachment)

  def reject_attachment!(invoice, message)
    invoice.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid.new(invoice)
  end

  def set_group
    @group = InvoiceGroup.find(params[:id])
    @current_season = @group.season
    session[:season_id] = @group.season_id
  end

  def group_invoice(invoice, draft_id)
    return invoice.invoice_group if invoice.invoice_group_id

    drafts = invoice.invoice_drafts.to_a
    source = drafts.find { |draft| draft.id == draft_id }
    original_ids = invoice.game_ids.sort
    ids = source&.data&.fetch("game_ids", nil)&.map(&:to_i)&.sort || original_ids
    if ids != original_ids && (invoice.ever_finalized? || invoice.editing_blocked?)
      invoice.errors.add(:games, "must match the saved games on invoices that have been finalized or are exporting")
    end
    raise ActiveRecord::RecordInvalid.new(invoice) if invoice.errors.any?
    verify_workbench_selections!(invoice, [ original_ids, ids ])

    group = InvoiceGroup.start!(season: invoice.season, game_ids: ids)
    link_invoice!(invoice, group)
    group
  end

  def verify_workbench_selections!(invoice, allowed_sets)
    return unless invoice.invoice_drafts.any? { |draft| draft.data.key?("game_ids") && !allowed_sets.include?(draft.data["game_ids"].map(&:to_i).sort) }

    invoice.errors.add(:games, "have pending changes in a workbench. Save and preview that selection before grouping this invoice.")
    raise ActiveRecord::RecordInvalid.new(invoice)
  end

  def link_invoice!(invoice, group)
    invoice.attach_to_group!(group)
    invoice.invoice_drafts.update_all(invoice_group_id: group.id, updated_at: Time.current)
  end

  def group_creation_origin(draft, invoice)
    return edit_invoice_draft_path(draft) if draft
    return invoice_path(invoice) if invoice

    games_path
  end
end
