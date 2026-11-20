require "test_helper"

class OfficialPaymentsSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 1200 ]

  test "records reviewed earnings and shows statement downloads" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Officials payments"
    assert_selector "h1", text: "Officials payments"
    fill_in "Name (Last, First)", with: "Aster, Cameron"
    click_button "Add official"
    assert_selector "h1", text: "Aster, Cameron"
    fill_in "Evaluations", with: "74.80"
    check "Earnings reconciled with the Horizon payroll report and any manual adjustments"
    fill_in "Cheque number", with: "FX-123"
    click_button "Save payment"
    assert_text "Official payment saved."
    assert_text "$74.80"
    assert_link "Download PDF"
    assert_link "Download editable document"
    assert_field "Evaluations", disabled: true
  end
end
