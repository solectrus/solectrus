describe 'Timeframe select' do
  before do
    stub_feature(:relative_timeframe)

    visit '/inverter_power/2022-06-21'
    wait_for_page_load
    open_timeframe_select
  end

  def wait_for_page_load
    expect(page).to have_css('#stats-day')
    expect(page).to have_css('#chart-day')
  end

  def open_timeframe_select
    # Open timeframe select modal
    click_on 'Für Zeitauswahl klicken'

    # Wait for modal content to load via Turbo Frame
    expect(page).to have_css('h1', text: 'Zeitraum wählen')
  end

  def close_current_picker
    # Close any open picker by clicking the back button
    # The back button shows "Anderer Zeitraum" text
    click_on 'Anderer Zeitraum'
    # Wait for the picker to actually close and main view to be visible
    expect(page).to have_content('Tag')
  end

  it 'displays modal with all pickers and options' do
    # Close the auto-opened day picker first to see all labels
    close_current_picker

    # Verify all picker labels are present
    expect(page).to have_content('Tag')
    expect(page).to have_content('Woche')
    expect(page).to have_content('Monat')
    expect(page).to have_content('Jahr')
    expect(page).to have_content('Individuell')
    expect(page).to have_css('button[data-value="P7D"]')
  end

  it 'navigates when selecting day picker' do
    # Day picker is auto-opened since we're on a day page
    # Day picker now uses custom button with data-date attribute
    find('button[data-date="2022-06-21"]').click

    expect(page).to have_current_path('/inverter_power/2022-06-21')
    expect(page).to have_css('#balance-stats-2022-06-21')
  end

  it 'navigates when selecting year picker' do
    # Close the auto-opened day picker first
    close_current_picker

    # Click the year picker button to open the modal
    find_by_id('year-picker-input-button').click

    find('button[data-year="2022"]').click

    expect(page).to have_current_path('/inverter_power/2022')
    expect(page).to have_css('#balance-stats-2022')
  end

  it 'navigates when selecting week picker' do
    # Close the auto-opened day picker first
    close_current_picker

    # Click the week picker button to open it
    find_by_id('week-picker-input-button').click

    find('button[data-week="2022-W25"]').click

    expect(page).to have_current_path('/inverter_power/2022-W25')
    expect(page).to have_css('#balance-stats-2022-W25')
  end

  it 'navigates when selecting month picker' do
    # Close the auto-opened day picker first
    close_current_picker

    # Click the month picker button to open it
    find_by_id('month-picker-input-button').click

    click_on 'Juni'

    expect(page).to have_current_path('/inverter_power/2022-06')
    expect(page).to have_css('#balance-stats-2022-06')
  end

  it 'navigates when selecting date range picker' do
    # Close the auto-opened day picker first
    close_current_picker

    # Click the range picker button to open it
    find_by_id('range-picker-input-button').click

    # Date range picker now uses custom buttons with data-date attribute
    find('button[data-date="2022-06-20"]').click
    find('button[data-date="2022-06-21"]').click

    expect(page).to have_current_path('/inverter_power/2022-06-20..2022-06-21')
    expect(page).to have_css('#balance-stats-2022-06-20--2022-06-21')
  end

  it 'navigates when selecting relative timeframe' do
    # Close the auto-opened day picker first
    close_current_picker

    # Relative options are displayed inline as grouped buttons
    find('button[data-value="P7D"]').click

    expect(page).to have_current_path('/inverter_power/P7D')
    expect(page).to have_css('#balance-stats-P7D')
  end
end
