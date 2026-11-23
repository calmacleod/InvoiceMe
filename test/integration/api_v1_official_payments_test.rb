require "test_helper"

class ApiV1OfficialPaymentsTest < ActionDispatch::IntegrationTest
  setup do
    @season = seasons(:current)
    _, token = ApiKey.issue!(user: users(:one), name: "Payment automation", write_access: true)
    @headers = { "Authorization" => "Bearer #{token}" }
  end

  test "seasons scope the register and read-only keys cannot change payments" do
    example = payment("Arden Example")
    other_year = Season.create!(year: @season.year - 1, sheet_name: "Fictional register", issuer: @season.issuer)
    other_year.official_payments.create!(official_name: "Blair Fiction")

    get api_v1_official_payments_path, params: { season_id: @season.id }
    assert_response :unauthorized

    _, token = ApiKey.issue!(user: users(:one), name: "Read register")
    headers = { "Authorization" => "Bearer #{token}" }
    get api_v1_official_payments_path, params: { season_id: @season.id }, headers: headers
    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    row = response.parsed_body.fetch("data").sole
    assert_equal [ example.id, 1, 0, 18_400 ], row.values_at("id", "payment_number", "banquet_cents", "net_cents")
    assert_not row.key?("assignments")

    get api_v1_official_payment_path(example), headers: headers
    assert_response :success
    assert_equal [], response.parsed_body.fetch("assignments")
    patch api_v1_official_payment_path(example), params: { official_payment: { lock_version: 0, banquet: "60.00" } }, headers: headers, as: :json
    assert_response :forbidden
    assert_equal 0, example.reload.banquet_cents
  end

  test "creates numbered manual payments and supports the reviewed cheque lifecycle" do
    post api_v1_official_payments_path, params: { season_id: @season.id, official_payment: { official_name: "Cameron Fable" } }, headers: @headers, as: :json
    assert_response :created
    id, version = response.parsed_body.values_at("id", "lock_version")
    assert_equal 1, response.parsed_body.fetch("payment_number")

    update_payment(id, version, evaluations: "200.00", banquet: "60.00", reviewed: true,
      adjustments: [ { label: "Fictional credit", amount: "12.50" } ])
    assert_response :success
    assert_equal 15_250, response.parsed_body.fetch("net_cents")
    assert_equal "Reviewed", response.parsed_body.fetch("status")

    update_payment(id, version, banquet: "120.00")
    assert_response :conflict

    update_payment(id, OfficialPayment.find(id).lock_version, cheque_number: "EX-0042", deposited_on: Date.current.iso8601)
    assert_response :success
    assert_equal "Deposited", response.parsed_body.fetch("status")

    update_payment(id, response.parsed_body.fetch("lock_version"), cheque_number: nil, deposited_on: nil, banquet: "120.00")
    assert_response :unprocessable_entity
    assert_equal 6000, OfficialPayment.find(id).banquet_cents
  end

  test "returns season totals for every earnings and deduction field" do
    payment("Arden Example", travel_ot_adjustment_cents: 235, evaluations_cents: 707, prepayment_refund_cents: 333,
      registration_cents: 2800, banquet_cents: 6000, next_year_prepayment_cents: 1222, other_cents: -69,
      adjustments: [ { "label" => "Fictional credit", "amount_cents" => 1200 }, { "label" => "Fictional deduction", "amount_cents" => -400 } ])
    payment("Blair Fiction", travel_ot_adjustment_cents: -50, banquet_cents: 12_000,
      adjustments: [ { "label" => "Fictional deduction", "amount_cents" => -200 } ])
    other_year = Season.create!(year: @season.year - 1, sheet_name: "Fictional register", issuer: @season.issuer)
    other_year.official_payments.create!(official_name: "Cameron Fable", evaluations_cents: 40_000)

    get totals_api_v1_official_payments_path, params: { season_id: @season.id }, headers: @headers
    assert_response :success
    assert_equal @season.id, response.parsed_body.fetch("season_id")
    assert_equal({
      "game_fee_adjustment_cents" => 40_000, "game_fees_cents" => 40_000,
      "travel_ot_adjustment_cents" => 185, "travel_ot_cents" => 185,
      "evaluations_cents" => 707, "prepayment_refund_cents" => 333, "other_cents" => -69, "additional_items_cents" => 600,
      "association_fee_cents" => 3200, "registration_cents" => 2800, "banquet_cents" => 18_000, "next_year_prepayment_cents" => 1222,
      "earnings_before_deductions_cents" => 38_556, "net_cents" => 16_534
    }, response.parsed_body.fetch("totals"))
  end

  test "bulk edits apply only the requested fields and replace or clear adjustments explicitly" do
    first = payment("Arden Example", registration_cents: 3500, reviewed_at: Time.current,
      adjustments: [ { "label" => "Existing fictional credit", "amount_cents" => 1250 } ])
    second = payment("Blair Fiction")
    batch(
      row(first, amounts: { banquet: "60.00" }),
      row(second, amounts: { banquet: "120.00" }, adjustments: [ { label: "Other fictional credit", amount: "3.50" } ])
    )
    assert_response :success
    assert_equal 2, response.parsed_body.fetch("updated")
    assert_equal [ 6000, 12_000 ], response.parsed_body.fetch("data").pluck("banquet_cents")
    assert_equal 3500, first.reload.registration_cents
    assert_equal 1250, first.adjustments.sole.fetch("amount_cents")
    assert_nil first.reviewed_at
    assert_equal 350, second.reload.adjustments.sole.fetch("amount_cents")

    batch(row(first, amounts: { banquet: "60.00" }), row(second, adjustments: []))
    assert_response :success
    assert_equal 1, response.parsed_body.fetch("updated")
    assert_empty second.reload.adjustments
  end

  test "bulk edits roll back for stale, locked, invalid, and out-of-season rows" do
    first = payment("Arden Example")
    second = payment("Blair Fiction", cheque_number: "EX-0010", reviewed_at: Time.current)
    first_change = row(first, amounts: { banquet: "60.00" })
    batch(first_change, row(second, amounts: { banquet: "60.00" }))
    assert_response :conflict
    assert_equal 0, first.reload.banquet_cents

    second.update!(cheque_number: nil)
    batch(first_change, row(second, amounts: { banquet: "60.00" }).merge(lock_version: 0))
    assert_response :conflict
    assert_equal 0, first.reload.banquet_cents

    batch(first_change, row(second, amounts: { banquet: "-60.00" }))
    assert_response :unprocessable_entity
    assert_equal 0, first.reload.banquet_cents

    other_year = Season.create!(year: @season.year - 1, sheet_name: "Fictional register", issuer: @season.issuer)
    outsider = other_year.official_payments.create!(official_name: "Cameron Fable")
    batch(first_change, row(outsider, amounts: { banquet: "60.00" }))
    assert_response :conflict
    assert_equal 0, first.reload.banquet_cents
  end

  test "previews draft statements and gates final document and sheet exports on review" do
    example = payment("Arden Example")
    get preview_api_v1_official_payment_path(example), headers: @headers
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes response.headers.fetch("Content-Disposition"), "inline"

    get pdf_api_v1_official_payment_path(example), headers: @headers
    assert_response :conflict
    post google_doc_api_v1_official_payment_path(example), headers: @headers
    assert_response :unprocessable_entity
    post export_sheet_api_v1_official_payments_path, params: { season_id: @season.id }, headers: @headers, as: :json
    assert_response :unprocessable_entity

    example.update!(reviewed_at: Time.current)
    get pdf_api_v1_official_payment_path(example), headers: @headers
    assert_response :success
    assert_equal "application/pdf", response.media_type
    get odt_api_v1_official_payment_path(example), headers: @headers
    assert_response :success
    assert_equal OdtDocument::MIME, response.media_type
  end

  test "queues and reports Horizon imports without reading credentials or running the job" do
    previous = ENV.to_h.slice("HORIZON_APP_ID", "HORIZON_APP_KEY")
    ENV.update("HORIZON_APP_ID" => "fictional-app", "HORIZON_APP_KEY" => "fictional-key")
    connection = HorizonConnection.create!(organization_name: "Fictional association", authorization_code: "fictional-code")
    args = { season_id: @season.id, horizon_connection_id: connection.id }

    assert_enqueued_jobs 1, only: OfficialPaymentImportJob do
      post imports_api_v1_official_payments_path, params: args, headers: @headers, as: :json
      assert_response :accepted
    end
    id = response.parsed_body.fetch("id")
    get import_api_v1_official_payments_path(id), params: { season_id: @season.id }, headers: @headers
    assert_response :success
    assert_equal "queued", response.parsed_body.fetch("status")

    get imports_api_v1_official_payments_path, params: { season_id: @season.id }, headers: @headers
    assert_response :success
    assert_equal [ { "id" => connection.id, "organization_name" => "Fictional association" } ], response.parsed_body.fetch("connections")
    post imports_api_v1_official_payments_path, params: args, headers: @headers, as: :json
    assert_response :conflict
  ensure
    %w[HORIZON_APP_ID HORIZON_APP_KEY].each { |key| ENV[key] = previous[key] }
  end

  test "reports a missing deployment credential even when an organization is connected" do
    previous = ENV.to_h.slice("HORIZON_APP_ID", "HORIZON_APP_KEY")
    ENV.delete("HORIZON_APP_KEY")
    connection = HorizonConnection.create!(organization_name: "Fictional association", authorization_code: "fictional-code")
    args = { season_id: @season.id, horizon_connection_id: connection.id }

    get imports_api_v1_official_payments_path, params: { season_id: @season.id }, headers: @headers
    assert_response :success
    assert_equal [ false, false ], response.parsed_body.values_at("horizon_configured", "can_import")
    assert_equal connection.id, response.parsed_body.fetch("connections").sole.fetch("id")

    assert_no_difference "OfficialPaymentImport.count" do
      post imports_api_v1_official_payments_path, params: args, headers: @headers, as: :json
      assert_response :unprocessable_entity
      assert_match(/deployment is missing its Horizon credentials/, response.parsed_body.fetch("error"))
    end
  ensure
    %w[HORIZON_APP_ID HORIZON_APP_KEY].each { |key| ENV[key] = previous[key] }
  end

  test "pulls revised Horizon fees and travel while retaining manual entries and recorded cheques" do
    previous = ENV.to_h.slice("HORIZON_APP_ID", "HORIZON_APP_KEY")
    original = Horizon::Client.method(:new)
    ENV.update("HORIZON_APP_ID" => "fictional-app", "HORIZON_APP_KEY" => "fictional-key")

    travel_to Time.zone.local(@season.year, 10, 1) do
      connection = HorizonConnection.create!(authorization_code: "fictional-code", organization_name: "Fictional association",
        access_token: "fictional-token", access_token_expires_at: 20.minutes.from_now)
      first = horizon_schedule_response(fee: 200, travel: 10, locked_fee: 300)
      revised = horizon_schedule_response(fee: 235.25, travel: 18.75, locked_fee: 325)
      replies = [ first, revised, revised ]
      requests = []
      client = Object.new
      client.define_singleton_method(:schedule) { self }
      client.define_singleton_method(:list) do |**filters|
        requests << filters
        replies.shift || raise("Unexpected Horizon request")
      end
      Horizon::Client.define_singleton_method(:new) { |**| client }

      initial = pull_horizon(connection)
      assert_equal [ "completed", 2, [] ], initial.values_at("status", "official_count", "changed_cheques")
      draft = @season.official_payments.find_by!(horizon_user_id: "fictional-draft")
      locked = @season.official_payments.find_by!(horizon_user_id: "fictional-cheque")
      assert_equal [ 20_000, 1000 ], [ draft.imported_game_fees_cents, draft.imported_travel_ot_cents ]
      manual = { game_fee_adjustment_cents: 235, travel_ot_adjustment_cents: -175, evaluations_cents: 4100,
        prepayment_refund_cents: 4200, registration_cents: 4375, banquet_cents: 6500, next_year_prepayment_cents: 4700, other_cents: 123,
        adjustments: [ { "label" => "Fictional credit", "amount_cents" => 975 } ] }
      draft.update!(manual.merge(reviewed_at: Time.current))
      locked.update!(cheque_number: "FX-472", reviewed_at: Time.current)
      standalone = payment("Fictional, Taylor", evaluations_cents: 5300, reviewed_at: Time.current)
      original_numbers = [ draft, locked, standalone ].map(&:payment_number)
      locked_before = locked.attributes
      standalone_before = standalone.attributes

      refresh = pull_horizon(connection)
      assert_equal [ "completed", 2, [ locked.id ] ], refresh.values_at("status", "official_count", "changed_cheques")
      assert_equal 3, @season.official_payments.count
      assert_equal [ 23_525, 1875 ], [ draft.reload.imported_game_fees_cents, draft.imported_travel_ot_cents ]
      assert_equal manual.stringify_keys, draft.attributes.slice(*manual.keys.map(&:to_s))
      assert_nil draft.reviewed_at
      assert_equal locked_before, locked.reload.attributes
      assert_equal standalone_before, standalone.reload.attributes
      assert_equal original_numbers, [ draft, locked, standalone ].map(&:payment_number)

      draft.update!(reviewed_at: Time.current)
      draft_before = draft.attributes
      assert_equal "completed", pull_horizon(connection).fetch("status")
      assert_equal draft_before, draft.reload.attributes
      assert_equal [ 1, 1, 1 ], requests.pluck(:page)
      assert_empty replies
    end
  ensure
    Horizon::Client.define_singleton_method(:new, original) if original
    %w[HORIZON_APP_ID HORIZON_APP_KEY].each { |key| ENV[key] = previous[key] }
  end

  private

  def pull_horizon(connection)
    perform_enqueued_jobs(only: OfficialPaymentImportJob) do
      post imports_api_v1_official_payments_path,
        params: { season_id: @season.id, horizon_connection_id: connection.id }, headers: @headers, as: :json
      assert_response :accepted
    end
    id = response.parsed_body.fetch("id")
    get import_api_v1_official_payments_path(id), params: { season_id: @season.id }, headers: @headers
    assert_response :success
    response.parsed_body
  end

  def horizon_schedule_response(fee:, travel:, locked_fee:)
    event = {
      "event_id" => "fictional-event", "event_start" => "#{@season.year}-08-15 12:00:00", "vouchered" => false, "cancelled" => "No",
      "assignment_count" => 2, "assignment" => [
        { "assignment_id" => "fictional-a", "user_id" => "fictional-draft", "first_name" => "Avery", "last_name" => "Example",
          "fee" => fee, "travel_fee" => travel, "accepted" => true },
        { "assignment_id" => "fictional-b", "user_id" => "fictional-cheque", "first_name" => "River", "last_name" => "Fable",
          "fee" => locked_fee, "accepted" => true }
      ]
    }
    { "current_page" => 1, "total_pages" => 1, "result_count" => 1, "result" => [ event ] }
  end

  def payment(name, **attributes)
    @season.official_payments.create!(official_name: name, game_fee_adjustment_cents: 20_000, **attributes)
  end

  def update_payment(id, version, **fields)
    patch api_v1_official_payment_path(id), params: { official_payment: fields.merge(lock_version: version) }, headers: @headers, as: :json
  end

  def row(payment, **fields)
    fields.merge(id: payment.id, lock_version: payment.lock_version)
  end

  def batch(*rows)
    patch bulk_update_api_v1_official_payments_path, params: { season_id: @season.id, payments: rows }, headers: @headers, as: :json
  end
end
