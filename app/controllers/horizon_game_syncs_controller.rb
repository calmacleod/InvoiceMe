class HorizonGameSyncsController < ApplicationController
  before_action :need_season

  def create
    Current.user.horizon_game_syncs.where(status: %w[ready failed discarded applied]).where("updated_at < ?", 2.hours.ago).delete_all
    connection = HorizonConnection.find(params[:horizon_connection_id])
    sync = HorizonGameSync.create!(season: current_season, user: Current.user, horizon_connection: connection)
    job = HorizonGameSyncJob.perform_later(sync.id)
    raise ActiveJob::EnqueueError unless job&.successfully_enqueued?
    redirect_to horizon_game_sync_path(sync), status: :see_other
  rescue ActiveRecord::RecordNotUnique
    redirect_to games_path, alert: "Another Horizon sync is running. Wait for it to finish."
  rescue ActiveJob::EnqueueError
    sync&.update!(status: "failed", error: "The sync could not be queued.")
    redirect_to games_path, alert: "The Horizon sync could not be queued."
  end

  def show
    sync = current_sync
    existing = sync.season.games.where(external_id: sync.games.map { |item| item.dig("attributes", "external_id") }).includes(:invoices).index_by(&:external_id)
    rows = sync.games.map do |item|
      attributes = item.fetch("attributes")
      record = existing[attributes.fetch("external_id")]
      changes = differences(record, attributes)
      { external_id: attributes.fetch("external_id"), date: attributes.fetch("date"), matchup: [ attributes["away_team"], attributes["home_team"] ].compact.join(" at "),
        status: record ? (changes.empty? ? "unchanged" : "changed") : "new", changes: changes, linked: record&.invoices&.any? || false }
    end
    render inertia: "games/HorizonSync", props: { sync: { id: sync.id, status: sync.status, error: sync.error, pages_fetched: sync.pages_fetched, total_pages: sync.total_pages,
      expired: sync.completed_at.present? && sync.completed_at <= 2.hours.ago, rows: rows } }
  end

  def destroy
    sync = current_sync
    raise ArgumentError, "A sync in progress cannot be discarded." if %w[queued running].include?(sync.status)
    sync.update!(status: "discarded", games: [])
    redirect_to games_path, status: :see_other, notice: "Horizon review discarded."
  rescue ArgumentError => error
    redirect_to horizon_game_sync_path(sync), alert: error.message
  end

  def apply
    current_sync.apply!
    redirect_to games_path, status: :see_other, notice: "Horizon games synchronized. Invoice links and invoicing marks were retained."
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_to horizon_game_sync_path(current_sync), alert: error.message
  end

  private

  def current_sync
    Current.user.horizon_game_syncs.where(season: current_season).find(params[:id])
  end

  def differences(record, attributes)
    fields = %w[date time code home_team away_team location officials fees_cents horizon_cancelled]
    fields.filter_map do |field|
      before = record&.public_send(field)
      before = before.iso8601 if before.is_a?(Date)
      after = attributes[field]
      next if before == after
      { field: field, before: before, after: after }
    end
  end
end
