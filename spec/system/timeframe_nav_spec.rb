describe 'Timeframe navigation' do
  before { stub_feature(:relative_timeframe) }

  # Measured in the browser on each call: a handle from `find` can point to a
  # tab bar that the chart frame has replaced in the meantime.
  def tab_bar_height
    page.evaluate_script(
      %(document.querySelector('nav[aria-label="Tabs"]').getBoundingClientRect().height),
    )
  end

  # The chart frame sends a fresh tab bar along when it arrives, so wait for it
  # before measuring one.
  def visit_settled(path, stats_id)
    visit path
    expect(page).to have_css("#stats-#{stats_id}")
  end

  def within_tabs(&) = within('nav[aria-label="Tabs"]', &)

  # optimistic-nav moves the marking to the tapped tab before the page it
  # points to arrives. A tab that opens a menu holds links of its own, and
  # those are not tabs: dressed as one, the tapped tab took the size of a menu
  # entry for as long as the page took to load, and the whole bar jumped.
  it 'keeps the height of the tab bar while a page loads' do
    visit_settled '/house_power/all', 'all'
    height = tab_bar_height

    within_tabs { click_on 'Jahr' }

    expect(page).to have_current_path(%r{/house_power/\d{4}\z})
    expect(tab_bar_height).to eq(height)
  end

  # The current tab opens a menu with the readings of its period. Picking one
  # navigates, and the bar keeps its height doing so.
  it 'navigates from the menu of the current tab' do
    visit_settled '/house_power/year', 'year'
    height = tab_bar_height

    within_tabs do
      click_on 'Jahr'
      click_on 'Letzte 12 Monate'
    end

    expect(page).to have_current_path('/house_power/P12M')
    expect(tab_bar_height).to eq(height)
  end
end
