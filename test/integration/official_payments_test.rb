require "test_helper"
require "pdf-reader"
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
    assert_nil payment.payment_number
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
    assert_equal 1, payment.payment_number
    assert_equal "Mailed", payment.cheque_delivery

    get pdf_official_payment_path(payment)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    page = PDF::Reader.new(StringIO.new(response.body)).pages.sole
    assert_includes page.text, "$3,098.60"
    assert_includes page.text, OfficialPaymentStatement::FEE_NOTE
    assert_includes page.text, @season.issuer.fetch("email")
    get odt_official_payment_path(payment)
    assert_response :success
    Zip::File.open_buffer(response.body) do |archive|
      content = Nokogiri::XML(archive.read("content.xml")) { |config| config.strict }
      assert_includes content.text, "Fable, Morgan"
      assert_includes content.text, "Cheque Number: EX-901"
      assert_includes content.text, "Payment Number: 1"
      assert_not_includes content.text, "2027 Prepayment"
      assert_not_includes content.text, "$0.00"
      assert_includes content.text, "$3,098.60"
      assert_includes content.text, OfficialPaymentStatement::FEE_NOTE
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

  test "previews a draft statement with named adjustments and removes them when cleared" do
    payment = @season.official_payments.create!(official_name: "Hollow, Riley")
    patch official_payment_path(payment), params: { official_payment: {
      lock_version: payment.lock_version, evaluations: "90.00",
      adjustments: [ { label: "Training credit", amount: "12.35" }, { label: "Equipment", amount: "-4.56" },
        { label: "Unused credit", amount: "0" } ]
    } }, as: :json
    assert_redirected_to edit_official_payment_path(payment)
    assert_equal 9_779, payment.reload.net_cents
    assert_nil payment.reviewed_at

    get preview_official_payment_path(payment)
    assert_response :success
    assert_match(/inline/, response.headers.fetch("Content-Disposition"))
    preview = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join
    assert_includes preview, "Training credit"
    assert_includes preview, "Equipment"
    assert_includes preview, "$97.79"
    assert_not_includes preview, "Unused credit"
    assert_not_includes preview, "Deductions"
    assert_not_includes preview, "Association Fee"
    assert_not_includes preview, "$0.00"
    assert_nil payment.reload.reviewed_at

    patch official_payment_path(payment), params: { official_payment: { lock_version: payment.lock_version, adjustments: [] } }, as: :json
    assert_empty payment.reload.adjustments
    assert_equal 9_000, payment.net_cents
  end

  test "amount grid saves different values per official and rolls back if a row is locked" do
    first = @season.official_payments.create!(official_name: "Fable, Avery", reviewed_at: Time.current, banquet_cents: 1_234)
    second = @season.official_payments.create!(official_name: "Birch, Riley", reviewed_at: Time.current)
    cheque = @season.official_payments.create!(official_name: "Shore, Morgan", reviewed_at: Time.current, evaluations_cents: 2_000, cheque_number: "F-903")
    get bulk_edit_official_payments_path
    assert_inertia_component "official_payments/BulkEdit"

    patch bulk_update_official_payments_path, params: { payments: [
      { id: first.id, lock_version: first.lock_version, amounts: { registration: "45.60" } },
      { id: second.id, lock_version: second.lock_version, amounts: { registration: "30.60", banquet: "3" } }
    ] }, as: :json
    assert_redirected_to bulk_edit_official_payments_path
    assert_equal [ 4_560, 3_060 ], [ first.reload.registration_cents, second.reload.registration_cents ]
    assert_equal 1_234, first.banquet_cents
    assert_nil first.reviewed_at
    assert_nil second.reviewed_at

    patch bulk_update_official_payments_path, params: { payments:
      [ first, cheque ].map { |payment| { id: payment.id, lock_version: payment.lock_version, amounts: { registration: "" } } }
    }, as: :json
    assert_equal 4_560, first.reload.registration_cents
    assert_equal 0, cheque.reload.registration_cents
  end

  test "dedicated adjustment register can add, move, and clear items across officials" do
    first = @season.official_payments.create!(official_name: "Larch, Avery", reviewed_at: Time.current,
      adjustments: [ { "label" => "Training waiver", "amount_cents" => 925 } ])
    second = @season.official_payments.create!(official_name: "Brook, Riley", reviewed_at: Time.current)
    get adjustments_official_payments_path
    assert_inertia_component "official_payments/Adjustments"
    patch update_adjustments_official_payments_path, params: { payments: [
      { id: first.id, lock_version: first.lock_version, items: [] },
      { id: second.id, lock_version: second.lock_version, items: [ { label: "Training waiver", amount: "9.25" }, { label: "Equipment", amount: "($2.10)" } ] }
    ] }, as: :json
    assert_redirected_to adjustments_official_payments_path
    assert_empty first.reload.adjustments
    assert_equal 715, second.reload.net_cents
    assert_nil first.reviewed_at
    assert_nil second.reviewed_at
  end

  test "payment numbers are assigned per year and separate from cheque numbers" do
    first = @season.official_payments.create!(official_name: "Reed, Avery")
    second = @season.official_payments.create!(official_name: "Brook, Riley", cheque_number: "0014", reviewed_at: Time.current, evaluations_cents: 3_000)
    year = Season.create!(year: 2034, sheet_name: "Fictional Register", issuer: @season.issuer)
    next_year = year.official_payments.create!(official_name: "Glen, Morgan", evaluations_cents: 1_000)
    assert_equal [ nil, 1, 1 ], [ first.payment_number, second.payment_number, next_year.payment_number ]
    assert_equal "0014", second.cheque_number
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
    payment.reload.update_from_form!({ private_note: "Treasurer-only check" }, user: users(:one), lock_version: payment.lock_version)
    post google_doc_official_payment_path(payment), headers: { "X-Inertia" => "true" }
    assert_equal 1, google.uploads.size

    payment.reload.update!(visible_note: "Mileage reimbursement included.")
    post google_doc_official_payment_path(payment), headers: { "X-Inertia" => "true" }
    assert_equal "file-1", google.uploads.last.fetch(:file_id)
    assert_equal 2, google.uploads.size
    Zip::File.open_buffer(google.uploads.last.fetch(:bytes)) do |archive|
      payload = archive.read("content.xml")
      assert_includes payload, "Mileage reimbursement included."
      assert_not_includes payload, "Treasurer-only check"
    end
  ensure
    GoogleApi.define_singleton_method(:new, constructor) if constructor
  end
end
