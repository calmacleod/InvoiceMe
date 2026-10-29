# Run with: RAILS_ENV=test bin/rails runner script/benchmark_workspace.rb
# Only fictional records, rolled back after measuring warm Inertia responses.
require "zlib"
abort "Use RAILS_ENV=test (never a development or production database)" unless Rails.env.test?

ActiveRecord::Base.transaction do
  season = Season.create!(year: 2198, sheet_name: "Benchmark", issuer: { name: "Fictional Association", treasurer: "Example Treasurer", email: "example@example.test", address: "Example address" })
  user = User.create!(email_address: "benchmark@example.test", password: "fictional-benchmark-password")
  now = Time.current
  games = 500.times.map do |i|
    officials = 6.times.map { |j| { name: "Fictional Official #{j}", position: "Example position", fee_cents: 1337 } }
    { season_id: season.id, external_id: "PERF-#{i}", code: "EXAMPLE", date: Date.new(2198, 2, 1) + i % 200,
      home_team: "Example Alpha", away_team: "Example Bravo", location: "Fictional Field", officials: officials, fees_cents: 8022,
      source: [ { "Paid By Team" => "No", "Officials/Positions" => officials.to_json, "Game ID#" => "PERF-#{i}" } ], created_at: now, updated_at: now }
  end
  Game.insert_all!(games)
  invoices = 250.times.map do |i|
    { season_id: season.id, number: "PERF_#{i}", recipient: "Example Club", description: "Fictional services", issued_on: Date.new(2198, 2, 1) + i % 200,
      finalized_at: i.even? ? now : nil, published_at: i.even? ? now : nil, created_at: now, updated_at: now }
  end
  ids = Invoice.insert_all!(invoices, returning: %w[id]).rows.flatten
  LineItem.insert_all!(ids.flat_map { |id| 5.times.map { |j| { invoice_id: id, description: "Example service", quantity: "2.5", rate_cents: 1337, position: j, created_at: now, updated_at: now } } })
  Payment.insert_all!(ids.each_slice(2).map { |id, _| { invoice_id: id, amount_cents: 1337, received_on: Date.new(2198, 2, 1), method: "Example", created_at: now, updated_at: now } })
  InvoiceGame.insert_all!(Game.where(season: season).pluck(:id).each_with_index.map { |id, i| { invoice_id: ids[i % ids.size], game_id: id, created_at: now, updated_at: now } })
  client = ActionDispatch::Integration::Session.new(Rails.application)
  client.post "/session", params: { email_address: user.email_address, password: "fictional-benchmark-password" }
  client.post "/select_year", params: { id: season.id }
  paths = [ "/", "/games", "/invoices/new", "/invoices/#{ids.first}" ]
  headers = { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
  metrics = paths.to_h do |path|
    request = -> { client.get path, headers: headers }
    5.times { request.call }
    samples = 11.times.map do
      queries = records = 0
      database_ms = 0.0
      sql = ->(*args) {
        event = args.last
        unless event[:cached] || event[:name] == "SCHEMA"
          queries += 1
          database_ms += (args[2] - args[1]) * 1000
        end
      }
      instantiate = ->(*args) { records += args.last[:record_count] }
      allocated = GC.stat(:total_allocated_objects)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      ActiveSupport::Notifications.subscribed(sql, "sql.active_record") do
        ActiveSupport::Notifications.subscribed(instantiate, "instantiation.active_record") { request.call }
      end
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      raise "Unexpected #{client.response.status} for #{path}" unless client.response.status == 200
      { ms: (elapsed * 1000).round(2), database_ms: database_ms.round(2), queries: queries, records: records, allocations: GC.stat(:total_allocated_objects) - allocated }
    end
    median = samples.sort_by { |sample| sample[:ms] }[5]
    [ path.sub(%r{/invoices/\d+}, "/invoices/:id"), median.merge(bytes: client.response.body.bytesize, gzip_bytes: Zlib.gzip(client.response.body).bytesize) ]
  end
  puts JSON.pretty_generate(dataset: { games: 500, invoices: 250, line_items: 1250, payments: 125 }, warm_median_of: 11, responses: metrics)
  raise ActiveRecord::Rollback
end
