require "test_helper"

class InertiaWorkspaceTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
  end

  test "Rails loads the extracted StyleX stylesheet with the React entrypoint" do
    get root_path
    assert_response :success
    assert_select "link[rel=stylesheet]" do |links|
      assert links.any? { |link| link["href"].include?("inertia-") && link["href"].end_with?(".css") }
    end
  end

  test "validation redirects provide errors to React without exposing credentials" do
    post invoices_path, params: { invoice: { number: "2031_Fictional", recipient: "Example club", description: "", issued_on: "2031-02-17" } }
    assert_redirected_to new_invoice_path
    follow_redirect!
    assert_inertia_component "invoices/Edit"
    assert inertia.props[:errors].key?("description")
    assert_equal({ "email" => users(:one).email_address }, inertia.props[:auth])
    refute_includes response.body, users(:one).password_digest
  end

  test "native Horizon export reaches React mapping and review with all assignments" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/horizon_master_fees.csv"), "text/csv")
    post upload_games_path, params: { file: file }
    follow_redirect!
    assert_inertia_component "games/Map"
    assert_equal "horizon_master_fees", inertia.props[:info]["format"]
    assert_equal 1, inertia.props[:info]["skipped_meetings"]
    mapping = GameImport.guess(inertia.props[:headers])
    post preview_games_path, params: { mapping: mapping, date_format: "%m/%d/%Y" }
    follow_redirect!
    assert_inertia_component "games/Review"
    assert_equal 3559, inertia.props[:totals][:fees]
    assert_empty inertia.props[:errors_list]
    assert_equal 0, @season.games.count
  end

  test "year validation returns to the React form" do
    patch season_path(@season), params: { season: { issuer: { email: "" } } }
    assert_redirected_to edit_season_path(@season)
    follow_redirect!
    assert_inertia_component "seasons/Edit"
    assert inertia.props[:errors].key?("issuer")
  end

  test "Google authorization uses a full page Inertia redirect" do
    original = ENV.to_h.slice("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET")
    ENV["GOOGLE_CLIENT_ID"] = "fictional-client"
    ENV["GOOGLE_CLIENT_SECRET"] = "fictional-secret"
    post google_connect_path, headers: { "X-Inertia" => "true" }
    assert_response :conflict
    assert_match %r{\Ahttps://accounts.google.com/o/oauth2/v2/auth\?}, response.headers["X-Inertia-Location"]
  ensure
    %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET].each do |key|
      original.key?(key) ? ENV[key] = original[key] : ENV.delete(key)
    end
  end

  test "sign out clears the encrypted Inertia history" do
    delete session_path, headers: { "X-Inertia" => "true" }
    assert_redirected_to new_session_path
    get new_session_path, headers: { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
    assert_response :success
    assert response.parsed_body["clearHistory"]
    assert_nil response.parsed_body.dig("props", "auth")
  end
end
