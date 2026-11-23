module Api
  module V1
    class InvoiceGroupsController < BaseController
      rescue_from ActiveRecord::StaleObjectError, with: -> { render_error("The group or draft has changed. Reload it and try again.", :conflict) }

      def index
        scope = season.invoice_groups.order(updated_at: :desc, id: :desc)
        render json: paginate(scope) { |record| group_summary(record) }
      end

      def show
        render json: group_details(group)
      end

      def create
        attrs = params.permit(:invoice_id, :draft_id, game_ids: [])
        unless attrs.values.count(&:present?) == 1
          raise ArgumentError, "Provide exactly one invoice_id, draft_id, or set of game_ids"
        end

        record = if attrs[:invoice_id].present?
          InvoiceGroup.for_invoice!(season.invoices.find(attrs[:invoice_id]))
        elsif attrs[:draft_id].present?
          InvoiceGroup.for_workbench!(@api_key.user.invoice_drafts.where(season: season).find(attrs[:draft_id]))
        else
          InvoiceGroup.start!(season: season, game_ids: attrs[:game_ids])
        end
        render json: group_details(record), status: record.previously_new_record? ? :created : :ok
      end

      def update
        attrs = params.permit(:name, game_ids: [])
        group.update_selection!(name: attrs.fetch(:name, group.name), game_ids: attrs[:game_ids], revision: params.require(:lock_version))
        render json: group_details(group)
      end

      def attachment
        invoice = group.season.invoices.find(params.require(:invoice_id))
        render json: group.attachment_review(invoice).merge(invoice_id: invoice.id, invoice_group_id: group.id)
      end

      def attach_invoice
        invoice = group.season.invoices.find(params.require(:invoice_id))
        group.attach_invoice!(invoice, review_token: params[:review_token])
        render json: group_details(group)
      end

      private

      def season = @season ||= Season.find(params.require(:season_id))
      def group = @group ||= InvoiceGroup.find(params[:id])

      def group_summary(record)
        record.as_json(only: %i[id name season_id lock_version])
      end

      def group_details(record)
        invoices = record.invoices.order(:id).includes(:line_items, :payments).map do |invoice|
          invoice.as_json(only: %i[id number recipient description finalized_at]).merge(status: invoice.status, total_cents: invoice.total_cents)
        end
        drafts = @api_key.user.invoice_drafts.where(invoice_group: record).open_work.summaries.map(&:metadata)
        group_summary(record).merge(game_ids: record.game_ids, games_locked: record.games_locked?,
          invoices: invoices, drafts: drafts, total_cents: invoices.sum { |invoice| invoice.fetch(:total_cents) })
      end
    end
  end
end
