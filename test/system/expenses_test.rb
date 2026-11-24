require "test_helper"

class ExpensesSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 1200 ]

  test "enters and pays an itemized association expense" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Association expenses"
    assert_text "Set this year’s Financials folder to sync."

    click_link "Add expense"
    fill_in "Vendor or member", with: "Old Mill Community Hall"
    fill_in "Description", with: "Fall volunteer workshop"
    set_date("incurred_on", "2026-11-05")
    fill_in "Full amount (CAD)", with: "99.65"
    select "Training and Evaluations", from: "Category"
    click_button "Add item"
    fill_in "Item 1 description", with: "Refreshments"
    select "Custom category…", from: "Item category (optional)"
    fill_in "Custom category name", with: "Meals"
    fill_in "Item amount (CAD)", with: "24.59"
    assert_text "Unitemized $75.06"
    click_button "Save expense"

    assert_text "Expense added"
    click_link "Fall volunteer workshop"
    assert_selector :select, "Category", selected: "Training and Evaluations"
    assert_selector :select, "Item category (optional)", selected: "Meals"
    assert_field "Item amount (CAD)", with: "24.59"
    check "Paid"
    set_date("paid_on", "2026-11-08")
    fill_in "Payment method (optional)", with: "Cheque"
    fill_in "Cheque number (optional)", with: "007"
    click_button "Save expense"

    assert_text "Expense saved"
    within("table[aria-label='Expenses']") { assert_text "007" }
    within("table[aria-label='Year totals by category']") do
      assert_text "Meals"
      assert_text "$24.59"
      assert_text "$75.06"
    end
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: false)
    within("table[aria-label='Expenses']") do
      assert_text "Cheque 007"
      assert_text "Training and Evaluations"
      assert_text "$99.65"
      assert evaluate_script("document.querySelector('[aria-label=Expenses]').parentElement.scrollWidth === document.querySelector('[aria-label=Expenses]').parentElement.clientWidth")
    end
    expense = Expense.find_by!(description: "Fall volunteer workshop")
    assert_equal [ Date.new(2026, 11, 5), true, Date.new(2026, 11, 8), "007" ],
      [ expense.incurred_on, expense.paid?, expense.paid_on, expense.cheque_number ]
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def set_date(id, value)
    # Use a native input event so React sees the same change as the date picker.
    execute_script(<<~JS, find("##{id}"), value)
      const input = arguments[0];
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(input, arguments[1]);
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end
end
