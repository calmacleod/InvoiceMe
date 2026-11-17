require "test_helper"

class HorizonGameSyncTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @connection = HorizonConnection.create!(authorization_code: "fictional-code")
    @sync = HorizonGameSync.create!(season: @season, user: users(:one), horizon_connection: @connection)
  end

  test "fetches every page once, stages differences, and applies without losing local flags or CSV source" do
    game = @season.games.create!(external_id: "fictional-1", date: Date.new(@season.year, 2, 17), fees_cents: 500, officials: [], source: [ { "Paid By Team" => "No" } ], already_invoiced: true)
    invoice = @season.invoices.create!(number: "2026_01_Fictional", recipient: "Fictional club", description: "Fees", issued_on: Date.current, line_items_attributes: [ { description: "Officials", quantity: 1, rate: "10" } ])
    invoice.games << game
    client = fake_client(page(1, 2, event("fictional-1")), page(2, 2, event("fictional-2")))
    with_fake_client(client) { HorizonGameSyncJob.perform_now(@sync.id) }
    assert_equal [ 1, 2 ], client.pages
    assert_equal "ready", @sync.reload.status
    assert_equal 2, @sync.games.size
    assert_equal 1, @season.games.count
    @sync.apply!
    assert_equal 2, @season.games.count
    assert_equal true, game.reload.already_invoiced
    assert_equal [ game.id ], invoice.reload.game_ids
    assert_equal "No", game.source.first.fetch("Paid By Team")
    assert_equal 1250, game.fees_cents
    assert_equal [ { "name" => "Fictional, Alex", "position" => "Referee", "fee_cents" => 1250 } ], game.officials
    assert_equal "applied", @sync.reload.status
    assert_raises(ArgumentError) { @sync.apply! }
  end

  test "inconsistent pages and duplicate IDs never produce a review" do
    [ [ page(1, 2, event("fictional-1")), page(1, 2, event("fictional-2")) ],
      [ page(1, 2, event("fictional-1")), page(2, 2, event("fictional-1")) ],
      [ page(1, 11, event("fictional-1")) ] ].each do |responses|
      @sync.update!(status: "queued", games: [])
      client = fake_client(*responses)
      with_fake_client(client) { HorizonGameSyncJob.perform_now(@sync.id) }
      assert_equal "failed", @sync.reload.status
      assert_empty @sync.games
      assert_equal 0, @season.games.count
    end
  end

  test "stale review is rejected atomically" do
    a = @season.games.create!(external_id: "fictional-1", date: Date.new(@season.year, 2, 17), fees_cents: 500)
    b = @season.games.create!(external_id: "fictional-2", date: Date.new(@season.year, 2, 17), fees_cents: 500)
    client = fake_client(page(1, 1, event("fictional-1"), event("fictional-2")))
    with_fake_client(client) { HorizonGameSyncJob.perform_now(@sync.id) }
    b.update!(code: "Changed after review")
    assert_raises(ArgumentError) { @sync.reload.apply! }
    assert_equal 500, a.reload.fees_cents
    assert_equal "ready", @sync.reload.status
  end

  test "incomplete assignments and unknown fee fail instead of silently importing partial data" do
    bad = event("fictional-1")
    bad["assignment_count"] = 2
    assert_raises(ArgumentError) { Horizon::GameMapper.call(bad) }
    bad = event("fictional-1")
    bad["assignment"].first["fee"] = nil
    assert_raises(ArgumentError) { Horizon::GameMapper.call(bad) }
  end

  private

  def event(id)
    { "event_id" => id, "event_start" => "#{@season.year}-02-17 13:30:00", "event_code" => { "name" => "Fictional League" },
      "home_team" => { "name" => "Fictional Home" }, "visiting_team" => { "name" => "Fictional Away" },
      "location" => { "name" => "Fictional Field" }, "cancelled" => "No", "assignment_count" => 1,
      "assignment" => [ { "first_name" => "Alex", "last_name" => "Fictional", "position" => "Referee", "fee" => 10.0, "travel_fee" => 2.5, "per_diem" => 0, "tolls" => 0, "other_fees" => 0, "deductions" => 1 } ] }
  end

  def page(current, total, *events)
    { "current_page" => current, "total_pages" => total, "result" => events }
  end

  def fake_client(*responses)
    Struct.new(:responses, :pages) do
      def schedule = self
      def list(**params)
        pages << params.fetch(:page)
        responses.shift || raise("Unexpected call")
      end
    end.new(responses, [])
  end

  def with_fake_client(client)
    original_client = Horizon::Client.method(:new)
    original_token = HorizonConnection.instance_method(:access_token_for_request)
    Horizon::Client.define_singleton_method(:new) { |**| client }
    HorizonConnection.define_method(:access_token_for_request) { "fictional-token" }
    yield
  ensure
    Horizon::Client.define_singleton_method(:new, original_client)
    HorizonConnection.define_method(:access_token_for_request, original_token)
  end
end
