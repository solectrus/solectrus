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

  it 'displays modal with all pickers and options' do
    # Verify all picker labels are present
    expect(page).to have_content('Tag')
    expect(page).to have_content('Woche')
    expect(page).to have_content('Monat')
    expect(page).to have_content('Jahr')
    expect(page).to have_content('Individuell')
    expect(page).to have_content('Relativ')
  end

  it 'navigates when selecting day picker' do
    page.find('label', text: 'Tag').click

    # Day picker now uses custom button with data-date attribute
    find('button[data-date="2022-06-21"]').click

    expect(page).to have_current_path('/inverter_power/2022-06-21')
    expect(page).to have_css('#balance-stats-2022-06-21')
  end

  it 'navigates when selecting year picker' do
    # Click the year picker button to open the modal
    click_on 'year-picker-input-button'

    find('button[data-year="2022"]').click

    expect(page).to have_current_path('/inverter_power/2022')
    expect(page).to have_css('#balance-stats-2022')
  end

  it 'navigates when selecting week picker' do
    page.find('label', text: 'Woche').click

    click_on 'KW 25'

    expect(page).to have_current_path('/inverter_power/2022-W25')
    expect(page).to have_css('#balance-stats-2022-W25')
  end

  it 'navigates when selecting month picker' do
    page.find('label', text: 'Monat').click

    click_on 'Juni'

    expect(page).to have_current_path('/inverter_power/2022-06')
    expect(page).to have_css('#balance-stats-2022-06')
  end

  it 'navigates when selecting date range picker' do
    page.find('label', text: 'Individuell').click

    # Date range picker now uses custom buttons with data-date attribute
    find('button[data-date="2022-06-20"]').click
    find('button[data-date="2022-06-21"]').click

    expect(page).to have_current_path('/inverter_power/2022-06-20..2022-06-21')
    expect(page).to have_css('#balance-stats-2022-06-20--2022-06-21')
  end

  it 'navigates when selecting relative timeframe' do
    page.find('label', text: 'Relativ').click

    click_on 'Letzte 7 Tage'

    expect(page).to have_current_path('/inverter_power/P7D')
    expect(page).to have_css('#balance-stats-P7D')
  end
end
