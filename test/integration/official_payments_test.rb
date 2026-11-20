require "test_helper"
require_relative "../test_helpers/fake_google"

class OfficialPaymentsTest < ActionDispatch::IntegrationTest
  class StatementDrive < FakeGoogle
    def request(method, url, **)
      raise "Unexpected Drive request" unless method == :get && url == "https://www.googleapis.com/drive/v3/files/root?fields=id"

      { "id" => "fictional-root" }
    end
  end

  setup do
    @season = seasons(:current)
    sign_in_as(users(:one))
  end

  test "creates, reviews, records a cheque, and downloads both statement formats" do
    post official_payments_path, params: { official_payment: { official_name: "Fable, Morgan" } }
    payment = @season.official_payments.sole
    assert_redirected_to edit_official_payment_path(payment)
    get edit_official_payment_path(payment)
    assert_inertia_component "official_payments/Edit"
    get pdf_official_payment_path(payment)
    assert_response :conflict

    patch official_payment_path(payment), params: { official_payment: {
      lock_version: payment.lock_version, reviewed: true, game_fee_adjustment: "3220.37",
      travel_ot_adjustment: "144.78", evaluations: "17", registration: "42.50", other: "-12.24",
      cheque_number: "EX-901", deposited_on: "2026-03-01", cheque_delivery: "Mailed"
    } }
    assert_redirected_to edit_official_payment_path(payment)
    assert_equal "Deposited", payment.reload.status
    assert_equal 22_881, payment.association_fee_cents
    assert_equal 309_860, payment.net_cents
    assert_equal "Mailed", payment.cheque_delivery

    get pdf_official_payment_path(payment)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert response.body.start_with?("%PDF")
    get odt_official_payment_path(payment)
    assert_response :success
    Zip::File.open_buffer(response.body) do |archive|
      content = Nokogiri::XML(archive.read("content.xml")) { |config| config.strict }
      assert_equal 14, content.xpath("//table:table-row").size
      assert_includes content.text, "Fable, Morgan"
      assert_includes content.text, "Cheque Number: EX-901"
      assert_includes content.text, "2027 Prepayment"
      assert_includes content.text, "$3098.60"
    end
  end

  test "rejects stale edits and locks recorded earnings until cheque information is cleared" do
    payment = @season.official_payments.create!(official_name: "Cloud, Taylor", evaluations_cents: 2_000, reviewed_at: Time.current, cheque_number: "EX-500")
    patch official_payment_path(payment), params: { official_payment: {
      lock_version: -1, reviewed: true, cheque_number: "EX-777"
    } }
    assert_redirected_to edit_official_payment_path(payment)
    assert_equal "EX-500", payment.reload.cheque_number
    patch official_payment_path(payment), params: { official_payment: {
      lock_version: payment.lock_version, reviewed: true, cheque_number: "", evaluations: "100"
    } }
    assert_redirected_to edit_official_payment_path(payment)
    assert_equal 2_000, payment.reload.evaluations_cents
    assert_equal "EX-500", payment.cheque_number
  end

  test "only serves statements within the selected year" do
    another_year = Season.create!(year: 2034, sheet_name: "Fictional Register", issuer: @season.issuer)
    payment = another_year.official_payments.create!(official_name: "Lake, Jordan", reviewed_at: Time.current)
    get pdf_official_payment_path(payment, season_id: @season.id)
    assert_response :not_found
    delete session_path
    get pdf_official_payment_path(payment)
    assert_redirected_to new_session_path
  end

  test "creates an editable Google Doc in treasurer Drive and updates the same file after corrections" do
    payment = @season.official_payments.create!(official_name: "Lake, Jordan", evaluations_cents: 2_000, reviewed_at: Time.current)
    google = StatementDrive.new
    constructor = GoogleApi.method(:new)
    GoogleApi.define_singleton_method(:new) { google }
    post google_doc_official_payment_path(payment), headers: { "X-Inertia" => "true" }
    assert_equal "https://docs.google.com/document/d/file-1/edit", response.headers["X-Inertia-Location"]
    assert_equal "fictional-root", google.uploads.sole.fetch(:folder)
    assert_equal "application/vnd.google-apps.document", google.uploads.sole.fetch(:target_mime)

    post google_doc_official_payment_path(payment), headers: { "X-Inertia" => "true" }
    assert_equal 1, google.uploads.size
    payment.reload.update!(cheque_number: "EX-701")
    post google_doc_official_payment_path(payment), headers: { "X-Inertia" => "true" }
    assert_equal "file-1", google.uploads.last.fetch(:file_id)
    assert_equal 2, google.uploads.size
  ensure
    GoogleApi.define_singleton_method(:new, constructor) if constructor
  end
end
