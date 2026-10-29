require "test_helper"
class WorkspaceTest < ActionDispatch::IntegrationTest
  def setup
    @season = seasons(:current)
  end
  test "workspace requires login and shows empty register" do
    get root_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    get root_path
    assert_response :success
    assert_select "h1", "Invoices."
    get new_invoice_path
    assert_response :success
    assert_select "template#line-item-template"
    get games_path
    assert_response :success
    get edit_season_path(@season)
    assert_response :success
    get preview_season_path(@season)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal 0, Invoice.count
  end
  test "create edit and preview an invoice then lock core changes after finalization" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    post invoices_path, params: { invoice: { number: "2026_Test", recipient: "Test club", description: "Test invoice", issued_on: "2026-10-29", line_items_attributes: { "0" => { description: "Officials", quantity: "4", rate: "100" }, "1793303374611" => { description: "Assigning", quantity: "1", rate: "100" } } } }
    invoice = Invoice.last
    assert_redirected_to invoice_path(invoice)
    get invoice_path(invoice)
    assert_response :success
    assert_select ".doc-total strong", "$500.00"
    get invoice_path(invoice, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    invoice.finalize!
    patch invoice_path(invoice), params: { invoice: { recipient: "Changed" } }
    assert_equal "Test club", invoice.reload.recipient
  end
  test "csv import goes through column mapping preview and commit" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/horizon.csv"), "text/csv")
    post upload_games_path, params: { file: file }
    assert_redirected_to map_games_path
    follow_redirect!
    assert_response :success
    post preview_games_path, params: { mapping: GameImport.guess([ "Game #", "Game Code", "Date", "Official", "Amount Paid" ]), date_format: "%Y-%m-%d" }
    assert_redirected_to review_games_path
    follow_redirect!
    assert_response :success
    post commit_games_path
    assert_redirected_to games_path
    assert_equal 1, @season.games.count
  end
end
