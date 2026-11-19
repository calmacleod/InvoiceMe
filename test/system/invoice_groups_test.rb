require "test_helper"

class InvoiceGroupsSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 1200 ]

  test "add a saved invoice from the group even when it has no games" do
    season = seasons(:current)
    game = season.games.create!(external_id: "EXAMPLE-ATTACH", date: Date.new(2031, 9, 15))
    group = InvoiceGroup.start!(season: season, game_ids: [ game.id ])
    invoice = season.invoices.create!(number: "EXAMPLE-STICK-CREW", recipient: "Example Club", description: "Stick crew", issued_on: game.date,
      line_items_attributes: [ { description: "Stick crew", quantity: 1, rate: "45.00" } ])
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1", text: "Invoices."

    visit invoice_group_path(group)
    click_link "Add existing invoice"
    find('[aria-label="Review EXAMPLE-STICK-CREW"]').click
    find("summary", text: "Games to add (1)").click
    assert_text "#EXAMPLE-ATTACH"
    click_button "Add invoice with shared games"
    within('section[aria-label="Invoices in this group"]') do
      assert_text "EXAMPLE-STICK-CREW"
      assert_text "$45.00"
    end
    assert_equal [ game.id ], invoice.reload.game_ids
  end

  test "start a group from games and switch payer drafts after reordering lines" do
    seasons(:current).games.create!(external_id: "EXAMPLE-GROUP", date: Date.new(2031, 9, 15))
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1", text: "Invoices."
    visit games_path
    find('[aria-label="Select game EXAMPLE-GROUP"]').check
    click_button "Start invoice group"
    assert_text "1 shared game"
    click_button "New invoice"
    fill_in "Bill to", with: "Example League"
    fill_in "description-0", with: "Example officials"
    click_button "+ Add amount-only item"
    fill_in "description-1", with: "Example travel"
    click_button "+ Add line item", exact: true
    fill_in "description-2", with: "Example assigning fee"

    source = find('[aria-label="Line item 1"] [draggable="true"]')
    target = find('[aria-label="Line item 3"]')
    source.drag_to(target)
    assert_field "description-0", with: "Example travel"
    assert_field "description-2", with: "Example officials"

    click_button "New invoice"
    assert_field "Bill to", with: ""
    fill_in "Bill to", with: "Example Club"
    fill_in "description-0", with: "Example stick crew"
    select "Example League", from: "group-invoice"
    assert_field "Bill to", with: "Example League"
    assert_field "description-2", with: "Example officials"
    select "Example Club", from: "group-invoice"
    assert_field "description-0", with: "Example stick crew"
    click_link "View group"
    within('section[aria-label="Invoices in this group"]') do
      assert_text "Example League"
      assert_text "Example Club"
    end
  end
end
