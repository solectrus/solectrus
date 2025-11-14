describe 'Forecast' do
  it 'displays the forecast page with chart' do
    visit '/forecast'

    expect(page).to have_current_path('/forecast')
    expect(page.title).to include('Prognose')

    # Check that navigation links are present
    expect(page).to have_link('Aktuell')
    expect(page).to have_link('Tag')
    expect(page).to have_link('Woche')
    expect(page).to have_link('Monat')
    expect(page).to have_link('Jahr')
    expect(page).to have_link('Gesamt')

    # Check that forecast timeframe navigation is present
    expect(page).to have_css('#forecast-timeframe')

    # The page should show "Morgen" navigation for forecast days
    expect(page).to have_text('Morgen')

    # Check that the forecast chart component is rendered
    expect(page).to have_css("[data-controller*='forecast-chart--component']")
  end

  it 'navigates to day view from forecast page' do
    visit '/forecast'

    # Find and click the "TAG" link
    first('a', text: 'TAG').click

    expect(page).to have_current_path('/inverter_power/day')
    expect(page).to have_css('#stats-day')
  end
end
