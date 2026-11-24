require "test_helper"

class ApiV1ExpensesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @season = seasons(:current)
    @write = headers(write_access: true)
    @read = headers(write_access: false)
  end

  test "records, filters, itemizes, pays and deletes an expense through the API" do
    get api_v1_expenses_path(season_id: @season.id)
    assert_response :unauthorized
    post api_v1_expenses_path, params: { season_id: @season.id, expense: details }, headers: @read, as: :json
    assert_response :forbidden

    post api_v1_expenses_path, params: { season_id: @season.id, expense: details }, headers: @write, as: :json
    assert_response :created
    created = response.parsed_body
    id = created.fetch("id")
    item_id = created.fetch("line_items").first.fetch("id")
    assert_equal [ 11005, 4990, 6015, false ], created.values_at("total_cents", "itemized_cents", "remainder_cents", "paid")
    assert_equal 1, @season.reload.expense_revision

    get api_v1_expenses_path(season_id: @season.id, category: "food", query: "Bay%", status: "unpaid"), headers: @read
    assert_response :success
    result = response.parsed_body
    assert_equal [ id ], result.fetch("data").pluck("id")
    assert_equal [ [ "Food", 4990 ], [ "Meetings", 6015 ] ],
      result.dig("summary", "by_category").map { |row| row.values_at("category", "unpaid_cents") }
    assert_includes result.fetch("categories"), "Food"
    get api_v1_expenses_path(season_id: @season.id, query: "Bay_"), headers: @read
    assert_empty response.parsed_body.fetch("data")

    patch api_v1_expense_path(id), params: { expense: { lock_version: created.fetch("lock_version"), paid: true, paid_on: "2026-12-04",
      payment_method: "Cheque", cheque_number: "0017", line_items: [ { id: item_id, description: "Snacks", category: "Food", amount_cents: 4790 } ] } },
      headers: @write, as: :json
    assert_response :success
    paid = response.parsed_body
    assert_equal [ true, "2026-12-04", "Cheque", "0017", 6215 ], paid.values_at("paid", "paid_on", "payment_method", "cheque_number", "remainder_cents")
    assert_equal item_id, paid.fetch("line_items").sole.fetch("id")
    assert_equal 2, @season.reload.expense_revision

    patch api_v1_expense_path(id), params: { expense: { lock_version: created.fetch("lock_version"), description: "Stale edit" } }, headers: @write, as: :json
    assert_response :conflict
    patch api_v1_expense_path(id), params: { expense: { notes: "Receipt received" } }, headers: @write, as: :json
    assert_response :success
    assert_equal item_id, response.parsed_body.fetch("line_items").sole.fetch("id")

    get api_v1_expense_path(id), headers: @read
    assert_response :success
    assert_equal "Receipt received", response.parsed_body.fetch("notes")
    get api_v1_expenses_path(season_id: @season.id, status: "unpaid"), headers: @read
    assert_empty response.parsed_body.fetch("data")
    assert_equal 11005, response.parsed_body.dig("summary", "paid_cents")

    assert_difference "ExpenseLineItem.count", -1 do
      delete api_v1_expense_path(id), headers: @write
    end
    assert_response :no_content
    assert_equal 4, @season.reload.expense_revision
    get api_v1_expense_path(id), headers: @read
    assert_response :not_found
  end

  test "invalid details and foreign line item IDs leave the saved expense intact" do
    other = @season.expenses.new
    other.save_details!(details)
    record = @season.expenses.new
    record.save_details!(details)
    attrs = record.details

    [ { paid: false, paid_on: "2026-12-04" }, { paid: "yes" }, { total_cents: 10 },
      { total_cents: 100.5 }, { line_items: { description: "Invalid shape" } },
      { line_items: [ { id: other.line_items.sole.id, description: "Other", amount_cents: 999 } ] } ].each do |invalid|
      patch api_v1_expense_path(record), params: { expense: invalid }, headers: @write, as: :json
      assert_response :unprocessable_entity
      assert_equal attrs, record.reload.details
    end

    patch api_v1_expense_path(record), params: { expense: { line_items: [] } }, headers: @write, as: :json
    assert_response :success
    assert_empty response.parsed_body.fetch("line_items")
    assert_equal 11005, response.parsed_body.fetch("remainder_cents")
  end

  test "configures a per-year financials folder and supports queuing and polling its sheet" do
    get api_v1_season_expense_sheet_path(@season), headers: @read
    assert_response :success
    assert_equal [ false, "idle" ], response.parsed_body.values_at("ready", "status")

    post api_v1_season_expense_sheet_path(@season), headers: @write
    assert_response :unprocessable_entity
    post api_v1_season_expense_sheet_path(@season), headers: @read
    assert_response :forbidden

    patch api_v1_season_path(@season), params: { season: { financials_folder_id: "https://drive.google.com/drive/folders/fictional-year-folder" } },
      headers: @write, as: :json
    assert_response :success
    assert_equal "fictional-year-folder", response.parsed_body.fetch("financials_folder_id")

    with_google_connection do
      assert_enqueued_jobs 1, only: SyncExpenseSheetJob do
        2.times do
          post api_v1_season_expense_sheet_path(@season), headers: @write
          assert_response :accepted
          assert_equal [ true, "queued", true ], response.parsed_body.values_at("ready", "status", "active")
        end
      end
      get api_v1_season_expense_sheet_path(@season), headers: @read
      assert_response :success
      assert_equal "queued", response.parsed_body.fetch("status")
    end
  end

  private

  def with_google_connection
    original = ENV.to_h.slice("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET")
    ENV.update("GOOGLE_CLIENT_ID" => "fictional-client", "GOOGLE_CLIENT_SECRET" => "fictional-secret")
    GoogleConnection.create!(email: "treasurer@example.test", refresh_token: "fictional-refresh-token")
    yield
  ensure
    %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET].each { |key| ENV[key] = original[key] }
  end

  def headers(write_access:)
    _, token = ApiKey.issue!(user: users(:one), name: "Example expense API key", write_access: write_access)
    { "Authorization" => "Bearer #{token}" }
  end

  def details
    { description: "Training venue and snacks", payee: "Bay% View Club", category: "Meetings", incurred_on: "2026-09-12", total_cents: 11005,
      line_items: [ { description: "Food", category: "Food", amount_cents: 4990 } ] }
  end
end
