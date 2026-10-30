require "test_helper"

class GameFiltersSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1100 ]

  test "searchable multi-selects use master options and combine selections in both browsers" do
    season = seasons(:current)
    3.times do |index|
      season.games.create!(external_id: "EXAMPLE-MULTI-#{index}", code: "Example Code #{index}", home_team: "Example Home #{index}", away_team: "Example Away #{index}", date: "2031-09-15")
    end
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1", text: "Invoices."
    [ games_path, new_invoice_path ].each do |path|
      visit path
      prefix = path == games_path ? "master" : "picker"
      find('summary[aria-label="Game code options"]').click
      fill_in "#{prefix}-code", with: "Code"
      check "Example Code 0"
      check "Example Code 1"
      find('summary[aria-label="Home team options"]').click
      fill_in "#{prefix}-home_team", with: "Home 1"
      check "Example Home 1"
      find('summary[aria-label="Away team options"]').click
      fill_in "#{prefix}-away_team", with: "Away 1"
      check "Example Away 1"
      click_button "Apply filters"
      assert_text "1 matching game"
      if path == new_invoice_path
        find("summary", text: "Filters ·").click
      end
      click_button "Clear filters"
      assert_text "3 matching games"
    end
  end
end
