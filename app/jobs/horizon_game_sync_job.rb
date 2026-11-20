class HorizonGameSyncJob < ApplicationJob
  queue_as :default

  def perform(id)
    sync = HorizonGameSync.find_by(id: id)
    return unless sync
    FileUtils.mkdir_p(Rails.root.join("storage/locks"))
    File.open(Rails.root.join("storage/locks/horizon-game-sync.lock"), "w") do |lock|
      return unless lock.flock(File::LOCK_EX | File::LOCK_NB)
      sync.reload
      return unless %w[queued running].include?(sync.status)
      sync.update!(status: "running")
      fetch_games(sync)
    end
  rescue Horizon::Client::Error, ArgumentError, ActiveRecord::RecordInvalid => error
    sync&.update!(status: "failed", error: error.message, games: [])
  rescue StandardError => error
    sync&.update!(status: "failed", error: "Horizon sync stopped unexpectedly. Try again.", games: [])
    Rails.error.report(error)
  end

  private

  def fetch_games(sync)
    client = Horizon::Client.new(access_token: sync.horizon_connection.access_token_for_request)
    year = sync.season.year
    results = Horizon::SchedulePages.fetch(client.schedule, start_date: "#{year}-01-01", end_date: "#{year}-12-31", event_type: "event") do |page, total|
      sync.update!(pages_fetched: page, total_pages: total)
    end
    if results.any? { |event| event["organization_event_id"].present? && event["organization_event_id"].to_s != event["event_id"].to_s }
      raise ArgumentError, "Horizon returned different event IDs and game numbers. Resolve the identity mapping before syncing."
    end
    mapped = results.reject { |event| event["type"].to_s.downcase == "meeting" }.map { |event| Horizon::GameMapper.call(event) }
    raise ArgumentError, "Horizon returned a game outside the requested year." unless mapped.all? { |game| Date.iso8601(game.fetch("date")).year == year }
    ids = mapped.map { |attributes| attributes.fetch("external_id") }
    raise ArgumentError, "Horizon returned duplicate game IDs. No games were changed." unless ids.uniq.size == ids.size
    existing = sync.season.games.where(external_id: ids).index_by(&:external_id)
    items = mapped.map do |attributes|
      record = existing[attributes.fetch("external_id")]
      { "attributes" => attributes, "existing_updated_at" => record&.updated_at&.iso8601(6) }
    end
    sync.update!(status: "ready", games: items, completed_at: Time.current)
  rescue KeyError, TypeError
    raise ArgumentError, "Horizon returned an incomplete schedule response. No games were changed."
  end
end
