require "test_helper"
require_relative "../test_helpers/fake_google"

class ApiV1InvoicePaymentChecksTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @season = seasons(:current)
    @path = api_v1_season_invoice_payment_check_path(@season)
    @read = headers(write_access: false)
    @write = headers(write_access: true)
    @original_google = GoogleApi.method(:new)
    @original_env = ENV.to_h.slice("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET")
    ENV.delete("GOOGLE_CLIENT_ID")
    ENV.delete("GOOGLE_CLIENT_SECRET")
  end

  teardown do
    GoogleApi.define_singleton_method(:new, @original_google)
    %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET].each { |key| ENV[key] = @original_env[key] }
  end

  test "requires authentication and write access and reports missing Google setup" do
    get @path
    assert_response :unauthorized
    post @path, headers: @read
    assert_response :forbidden
    get @path, headers: @read
    assert_response :success
    assert_equal [ false, "idle", false ], response.parsed_body.values_at("ready", "status", "active")
    assert_no_enqueued_jobs do
      post @path, headers: @write
      assert_response :unprocessable_entity
    end
  end

  test "queues and reports a check that records a ledger payment exactly once" do
    api = connect_google
    invoice = published_invoice
    date = Date.new(2024, 11, 5)
    api.rows[5] = [ invoice.number, "", "", "", 26.74, 26.74, 0, "Cheque", date.iso8601 ]

    assert_enqueued_jobs 1, only: CheckInvoicePaymentsJob do
      2.times do
        post @path, headers: @write
        assert_response :accepted
        assert_equal [ true, "queued", true ], response.parsed_body.values_at("ready", "status", "active")
      end
    end
    assert_difference "Payment.count", 1 do
      perform_enqueued_jobs(only: CheckInvoicePaymentsJob)
    end
    get @path, headers: @read
    assert_response :success
    assert_equal [ "succeeded", false, 1, 1, 0 ],
      response.parsed_body.values_at("status", "active", "checked_count", "imported_count", "review_count")
    assert response.parsed_body.fetch("finished_at")

    get api_v1_invoice_path(invoice), headers: @read
    assert_response :success
    assert_equal [ "Paid", 2674, 0 ], response.parsed_body.values_at("status", "received_cents", "owed_cents")
    assert_equal [ 2674, "Cheque", date.iso8601 ],
      response.parsed_body.fetch("payments").sole.values_at("amount_cents", "method", "received_on")

    assert_no_difference "Payment.count" do
      perform_enqueued_jobs { post @path, headers: @write }
    end
    assert_empty api.writes
    assert_empty api.uploads
  end

  test "scheduled and browser triggers use the same check" do
    connect_google
    published_invoice
    Season.create!(year: 2031, sheet_name: "2031 invoices", issuer: @season.issuer)

    assert_enqueued_jobs 1, only: CheckInvoicePaymentsJob do
      CheckInvoicePaymentsJob.perform_now
    end

    sign_in_as(users(:one))
    assert_no_enqueued_jobs do
      post check_payments_invoices_path, params: { season_id: @season.id, q: "Example", per_page: 10 }
      assert_redirected_to root_path(season_id: @season.id, q: "Example", per_page: 10)
    end
    follow_redirect! headers: { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
    assert_response :success
    assert_equal "queued", response.parsed_body.dig("props", "payment_check", "status")
  end

  test "reports a Google read failure and accepts another check" do
    api = connect_google
    published_invoice
    api.define_singleton_method(:validate_ledger_headers) do |_|
      raise GoogleApi::Error, "Fictional ledger headers changed."
    end

    assert_no_difference "Payment.count" do
      perform_enqueued_jobs { post @path, headers: @write }
    end
    get @path, headers: @read
    assert_equal [ "failed", false, "Fictional ledger headers changed." ],
      response.parsed_body.values_at("status", "active", "error")
    assert_enqueued_with(job: CheckInvoicePaymentsJob) { post @path, headers: @write }
    assert_response :accepted
  end

  private

  def headers(write_access:)
    _, token = ApiKey.issue!(user: users(:one), name: "Example ledger API key", write_access: write_access)
    { "Authorization" => "Bearer #{token}" }
  end

  def connect_google
    ENV.update("GOOGLE_CLIENT_ID" => "fictional-client", "GOOGLE_CLIENT_SECRET" => "fictional-secret")
    GoogleConnection.create!(email: "treasurer@example.test", refresh_token: "fictional-refresh-token")
    api = FakeGoogle.new
    GoogleApi.define_singleton_method(:new) { api }
    api
  end

  def published_invoice
    @season.update!(spreadsheet_id: "fictional-ledger")
    invoice = @season.invoices.create!(number: "2026_Example", recipient: "Example Club", description: "Fictional services",
      issued_on: "2024-11-01", line_items_attributes: [ { description: "Example", quantity: 2, rate: "13.37" } ])
    invoice.finalize!
    invoice.update!(published_at: Time.current, ledger_row: 3)
    invoice
  end
end
