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

  test "shows all amount columns, named items and totals for the displayed officials" do
    season = seasons(:current)
    season.official_payments.create!(official_name: "Birch, Riley", game_fee_adjustment_cents: 20_000,
      evaluations_cents: 7000, registration_cents: 1975, banquet_cents: 6000, other_cents: -1040,
      adjustments: [ { "label" => "Fictional training credit", "amount_cents" => 2000 }, { "label" => "Fictional equipment deduction", "amount_cents" => -800 } ])
    season.official_payments.create!(official_name: "River, Morgan", banquet_cents: 12_000)

    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Officials payments"

    within '[aria-labelledby="earnings-register-heading"]' do
      headings = [
        "Official", "Game fees incl. adj.", "Game fee adj.", "Travel/OT incl. adj.", "Travel/OT adj.", "Evaluations", "Prepayment refund", "Other", "Additional items",
        "Association fee", "OFOA registration", "Banquet", "Next year’s prepayment", "Net earnings", "Cheque", "Deposited", "Status"
      ]
      assert_equal headings.map(&:upcase), all("thead th").map { |heading| heading.text.squish.upcase }
      assert_selector "tbody tr", count: 2
      assert_text "Fictional training credit"
      assert_text "Fictional equipment deduction"
      assert_text "-$8.00"
      assert_selector "tfoot th", text: "Season totals"
      assert_selector "tfoot td", exact_text: "$180.00"
      assert_selector "tfoot td", exact_text: "$12.00"
      assert_equal "sticky", evaluate_script("getComputedStyle(document.querySelector('tfoot')).position")
    end

    fill_in "Search officials", with: "Birch"
    assert_selector "tfoot th", text: "Search totals"
    assert_selector "tfoot td", exact_text: "$60.00"
    assert_no_selector "tfoot td", exact_text: "$180.00"
    assert_no_link "River, Morgan"
  end

  test "pastes different amounts into the payment grid and navigates by keyboard" do
    season = seasons(:current)
    first = season.official_payments.create!(official_name: "Birch, Riley")
    second = season.official_payments.create!(official_name: "River, Morgan")
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Officials payments"
    click_link "Enter payment amounts"
    registration = find('[aria-label="OFOA registration for Birch, Riley"]')
    registration.click
    registration.send_keys(:enter)
    assert_selector '[aria-label="OFOA registration for River, Morgan"]:focus'
    execute_script(<<~JS, registration, "$40.60\t12.30\n30.50\t9.10")
      const clipboard = new DataTransfer();
      clipboard.setData("text/plain", arguments[1]);
      arguments[0].dispatchEvent(new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: clipboard }));
    JS
    click_button "Save amounts"
    assert_text "Updated 2 officials."
    assert_equal [ 4_060, 3_050 ], [ first.reload.registration_cents, second.reload.registration_cents ]
    assert_equal [ 1_230, 910 ], [ first.banquet_cents, second.banquet_cents ]
  end

  test "enters named adjustments for different officials from one page" do
    season = seasons(:current)
    first = season.official_payments.create!(official_name: "Birch, Riley")
    second = season.official_payments.create!(official_name: "River, Morgan")
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Officials payments"
    click_link "Additional items"
    click_button "Add row"
    find('[aria-label="Official for item 1"]').select("1. Birch, Riley")
    find('[aria-label="Item 1 reason"]').send_keys("Mileage correction")
    find('[aria-label="Item 1 amount"]').send_keys("14.60")
    assert_selector '[aria-label="Item 1 amount"][value="14.60"]'
    click_button "Add row"
    find('[aria-label="Official for item 2"]').select("2. River, Morgan")
    find('[aria-label="Item 2 reason"]').send_keys("Equipment")
    find('[aria-label="Item 2 amount"]').send_keys("-7.20")
    assert_selector '[aria-label="Item 2 amount"][value="-7.20"]'
    click_button "Save additional items"
    assert_text "Updated 2 officials."
    assert_equal 1_460, first.reload.net_cents
    assert_equal(-720, second.reload.net_cents)
  end
end
