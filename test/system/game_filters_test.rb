require "test_helper"

class GameFiltersSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1100 ]

  setup do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1", text: "Invoices."
  end

  test "searchable multi-selects use master options and combine selections in both browsers" do
    season = seasons(:current)
    3.times do |index|
      season.games.create!(external_id: "EXAMPLE-MULTI-#{index}", code: "Example Code #{index}", home_team: "Example Home #{index}", away_team: "Example Away #{index}", date: "2031-09-15")
    end
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

  test "sorting and page sizes persist across pages and filters including both pickers" do
    32.times do |index|
      seasons(:current).games.create!(external_id: "EXAMPLE-PAGE-#{index.to_s.rjust(2, '0')}", date: "2031-09-15", fees_cents: index * 100)
      users(:one).contacts.create!(name: "Example Contact #{index}")
    end
    visit games_path
    select "10", from: "Per page"
    assert_selector "tbody tr", count: 10
    find('button[aria-label="Sort by total fees"]:not(:disabled)').click
    assert_selector 'th[aria-sort="ascending"]', text: /total fees/i
    find('button[aria-label="Sort by total fees"]:not(:disabled)').click
    assert_selector 'th[aria-sort="descending"]', text: /total fees/i
    assert_selector "tbody tr:first-child", text: "EXAMPLE-PAGE-31"
    click_link "Next →"
    assert_text "Page 2 of 4"
    assert_selector "tbody tr:first-child", text: "EXAMPLE-PAGE-21"
    select "50", from: "Per page"
    assert_text "Page 1 of 1"
    assert_selector "tbody tr", count: 32
    fill_in "master-q", with: "EXAMPLE-PAGE-0"
    click_button "Apply filters"
    assert_text "10 matching games"
    assert_selector :select, "Per page", selected: "50"
    assert_selector "tbody tr:first-child", text: "EXAMPLE-PAGE-09"

    [ root_path, contacts_path, invoice_drafts_path ].each do |path|
      visit path
      select "50", from: "Per page"
      assert_selector :select, "Per page", selected: "50"
    end

    visit new_invoice_path
    within('nav[aria-label="Game browser pagination"]') { select "10", from: "Per page" }
    assert_selector "tbody tr", count: 10
    click_button "Link this page"
    click_button "Linked games (10)"
    within('nav[aria-label="Linked games pagination"]') do
      select "50", from: "Per page"
      assert_selector :select, "Per page", selected: "50"
    end
    assert_selector "tbody tr", count: 10
    click_button "Choose a saved recipient"
    within('nav[aria-label="Saved contact pagination"]') do
      select "10", from: "Per page"
      assert_text "1–10 of 32"
      click_button "Next contacts →"
      assert_text "11–20 of 32"
      select "50", from: "Per page"
      assert_text "1–32 of 32"
    end
  end

  test "linked game counts by code include every page and survive saving the draft" do
    32.times do |index|
      seasons(:current).games.create!(external_id: "EXAMPLE-CODE-#{index.to_s.rjust(2, '0')}", code: index < 25 ? "EXAMPLE-ALPHA" : "EXAMPLE-BETA", date: "2031-09-15")
    end
    visit new_invoice_path
    assert_no_selector 'section[aria-label="Games by game code"]'
    click_button "Link this page"
    within('section[aria-label="Games by game code"]') do
      assert_selector "dt", text: "EXAMPLE-ALPHA"
      assert_selector "dd", text: "25 games"
      assert_no_text "EXAMPLE-BETA"
    end
    click_button "Next →"
    assert_selector "tbody tr", count: 7
    click_button "Link this page"
    within('section[aria-label="Games by game code"]') do
      assert_selector "dd", text: "25 games"
      assert_selector "dt", text: "EXAMPLE-BETA"
      assert_selector "dd", text: "7 games"
    end
    find('input[aria-label="Select game EXAMPLE-CODE-25"]').set(false)
    within('section[aria-label="Games by game code"]') { assert_selector "dd", text: "6 games" }
    assert_text "All changes saved"
    draft_path = page.current_path
    visit games_path
    visit draft_path
    within('section[aria-label="Games by game code"]') do
      assert_selector "dd", text: "25 games"
      assert_selector "dd", text: "6 games"
    end
  end

  test "sort filtered matches link every page and expand a code to all of its linked games" do
    35.times do |index|
      seasons(:current).games.create!(external_id: "EXAMPLE-ALL-#{index.to_s.rjust(2, '0')}", code: index < 30 ? "EXAMPLE-ALPHA" : "EXAMPLE-BETA", date: "2031-09-15", fees_cents: index * 100)
    end
    visit new_invoice_path
    find('input[aria-label="Select game EXAMPLE-ALL-00"]').set(true)
    find('summary[aria-label="Game code options"]').click
    check "EXAMPLE-BETA"
    click_button "Apply filters"
    assert_text "5 matching games"
    click_button "Link all matching games (5)"
    assert_button "Linked games (6)"
    find("summary", text: "Filters ·").click
    code_options = find('summary[aria-label="Game code options"]')
    code_options.click unless code_options.find(:xpath, "..")[:open]
    uncheck "EXAMPLE-BETA"
    check "EXAMPLE-ALPHA"
    click_button "Apply filters"
    assert_text "30 matching games"
    within('nav[aria-label="Game browser pagination"]') { select "10", from: "Per page" }
    find('button[aria-label="Sort by total fees"]:not(:disabled)').click
    assert_selector 'th[aria-sort="ascending"]', text: /total fees/i
    find('button[aria-label="Sort by total fees"]:not(:disabled)').click
    assert_selector 'th[aria-sort="descending"]', text: /total fees/i
    assert_selector "tbody tr:first-child", text: "EXAMPLE-ALL-29"
    click_button "Next →"
    assert_text "Page 2 of 3"
    assert_selector "tbody tr:first-child", text: "EXAMPLE-ALL-19"
    click_button "Link all matching games (30)"
    assert_button "Linked games (35)"
    click_button "Link all matching games (30)"
    assert_button "Linked games (35)"
    click_button "EXAMPLE-ALPHA"
    within('section[aria-label="Linked games for EXAMPLE-ALPHA"]') do
      assert_selector "tbody tr", count: 30
      assert_text "EXAMPLE-ALL-00"
      assert_text "EXAMPLE-ALL-29"
      assert_no_text "EXAMPLE-ALL-30"
    end
    click_button "Close game breakdown"
    click_button "Linked games (35)"
    find('button[aria-label="Sort by total fees"]:not(:disabled)').click
    assert_selector 'th[aria-sort="ascending"]', text: /total fees/i
    assert_selector "tbody tr:first-child", text: "EXAMPLE-ALL-00"
    assert_text "All changes saved"
    draft_path = page.current_path
    visit games_path
    visit draft_path
    assert_button "Linked games (35)"
    click_button "EXAMPLE-BETA"
    within('section[aria-label="Linked games for EXAMPLE-BETA"]') { assert_selector "tbody tr", count: 5 }
  end
end
