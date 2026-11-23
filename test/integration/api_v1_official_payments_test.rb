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

  private

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
