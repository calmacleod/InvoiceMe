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
    assert_link "Preview statement"
    fill_in "Evaluations", with: "74.80"
    click_button "Add item"
    fill_in "Item 1 name", with: "Mileage correction"
    fill_in "Item 1 amount", with: "12.20"
    check "Earnings reconciled with the Horizon payroll report and any manual adjustments"
    fill_in "Cheque number", with: "FX-123"
    click_button "Save payment"
    assert_text "Official payment saved."
    assert_text "$87.00"
    assert_link "Download PDF"
    assert_link "Download editable document"
    assert_field "Evaluations", disabled: true
  end

  test "sets a fee for multiple selected officials" do
    season = seasons(:current)
    first = season.official_payments.create!(official_name: "Birch, Riley")
    second = season.official_payments.create!(official_name: "River, Morgan")
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Officials payments"
    click_link "Bulk edit amounts"
    fill_in "OFOA registration", with: "40.60"
    click_button "Select all editable"
    click_button "Apply to 2 selected"
    assert_text "Updated 2 officials."
    assert_equal [ 4_060, 4_060 ], [ first.reload.registration_cents, second.reload.registration_cents ]
  end
end
