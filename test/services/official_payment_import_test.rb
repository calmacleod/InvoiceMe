require "test_helper"

class OfficialPaymentImportTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @from = Date.new(@season.year, 1, 1)
    @through = Date.new(@season.year, 5, 31)
    @connection = HorizonConnection.new(id: 110, organization_name: "Fictional Officials")
  end

  test "groups complete pages by stable user ID and refreshes draft amounts without changing cheques" do
    first = game("fictional-1", assignment("assignment-a", "official-a", fee: 80, travel_fee: 12.50))
    second = game("fictional-2", assignment("assignment-b", "official-a", fee: 120, other_fees: 8), assignment("assignment-c", "official-b", fee: 80))
    exterior = game("fictional-3", assignment("assignment-d", "official-a", fee: 500)).merge("vouchered" => true)
    unknown = game("fictional-4", assignment("assignment-e", "official-a", fee: 500)).except("vouchered")
    source = fake_schedule(page(1, 2, first, exterior), page(2, 2, second, unknown))
    rows, excluded = fetch(source)
    assert_equal [ 1, 2 ], source.requests.map { |request| request.fetch(:page) }
    assert_equal({ start_date: @from.iso8601, end_date: @through.iso8601, event_type: "event", published: true, cancelled: false }, source.requests.first.except(:page))
    assert_equal [ "fictional-4" ], excluded

    @season.official_payment_imports.create!(status: "running").apply!(rows, excluded, connection: @connection)
    editable = @season.official_payments.find_by!(horizon_user_id: "official-a")
    issued = @season.official_payments.find_by!(horizon_user_id: "official-b")
    assert_equal editable.official_name, issued.official_name
    assert_equal 20_000, editable.game_fees_cents
    assert_equal 2_050, editable.travel_ot_cents
    assert_equal 1_600, editable.horizon_deductions_cents
    editable.update!(other_cents: 900, reviewed_at: Time.current)
    issued.update!(cheque_number: "F1001", reviewed_at: Time.current)

    replacement, skipped = fetch(fake_schedule(page(1, 1, first)))
    refresh = @season.official_payment_imports.create!(status: "running")
    refresh.apply!(replacement, skipped, connection: @connection)
    assert_equal [ issued.id ], refresh.changed_cheques
    assert_equal 8_000, editable.reload.game_fees_cents
    assert_equal 900, editable.other_cents
    assert_nil editable.reviewed_at
    assert_equal 8_000, issued.reload.game_fees_cents
    assert_equal "F1001", issued.cheque_number
  end

  test "accepts a completely empty schedule and rejects duplicates and incomplete pages" do
    assert_equal [ {}, [] ], fetch(fake_schedule(page(0, 0)))
    event = game("fictional-1", assignment("assignment-a", "official-a", fee: 80))
    assert_raises(Horizon::Client::ResponseError) { fetch(fake_schedule(page(1, 2, event), page(2, 2, event))) }
    assert_raises(Horizon::Client::ResponseError) { fetch(fake_schedule(page(1, 2, event), page(2, 2))) }
    assert_raises(Horizon::Client::ResponseError) { fetch(fake_schedule(page(1, 1, event.merge("assignment_count" => 2)))) }
  end

  test "only one queued or running import can exist even across seasons" do
    first = @season.official_payment_imports.create!
    first.update!(status: "running")
    another_year = Season.create!(year: 2034, sheet_name: "Fictional Register", issuer: @season.issuer)
    assert_raises(ActiveRecord::RecordNotUnique) { another_year.official_payment_imports.create! }
  end

  test "stalled imports can be replaced and a late job cannot apply an expired result" do
    stalled = @season.official_payment_imports.create!(status: "running", updated_at: 35.minutes.ago)
    assert_equal "failed", stalled.props.fetch("status")
    OfficialPaymentImport.expire_stalled!
    assert_equal "failed", stalled.reload.status
    @season.official_payment_imports.create!
    stalled.apply!({}, [], connection: @connection)
    assert_equal "failed", stalled.reload.status
  end

  test "a reconnect requires common Horizon event IDs when the register has imported earnings" do
    event = game("fictional-1", assignment("assignment-a", "official-a", fee: 80))
    rows, ignored = fetch(fake_schedule(page(1, 1, event)))
    @season.official_payment_imports.create!(status: "running").apply!(rows, ignored, connection: @connection)
    replacement = HorizonConnection.new(id: 111)
    import = @season.official_payment_imports.create!(status: "running")
    assert_raises(Horizon::Client::ConfigurationError) { import.apply!({}, [], connection: replacement) }
    assert_equal 8_000, @season.official_payments.sole.game_fees_cents

    import.apply!(rows, ignored, connection: replacement)
    assert_equal 111, import.horizon_connection_id
    assert_equal "completed", import.status
  end

  private

  def fetch(schedule)
    Horizon::OfficialEarnings.new(schedule, from: @from, through: @through).fetch
  end

  def game(id, *assignments)
    { "event_id" => id, "event_start" => "#{@season.year}-03-14 13:00:00", "vouchered" => false, "cancelled" => "No",
      "assignment" => assignments, "assignment_count" => assignments.size }
  end

  def assignment(id, user, **amounts)
    { "assignment_id" => id, "user_id" => user, "first_name" => "Morgan", "last_name" => "Fable",
      "accepted" => true, "position" => "Referee", "deductions" => 0.08 }.merge(amounts.stringify_keys)
  end

  def page(current, total, *events)
    { "current_page" => current, "total_pages" => total, "result_count" => events.size, "result" => events }
  end

  def fake_schedule(*responses)
    Struct.new(:responses, :requests) do
      def list(**params)
        requests << params
        responses.shift || raise("Unexpected Horizon call")
      end
    end.new(responses, [])
  end
end
