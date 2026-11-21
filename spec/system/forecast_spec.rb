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

    # The page shows today and tomorrow first
    expect(page).to have_text('Heute und morgen')

    # Check that the inverter power forecast chart is loaded and displayed
    within('#inverter-power-forecast-chart') do
      expect(page).to have_css('canvas')
    end

    # Check that the outdoor temperature forecast chart is loaded and displayed
    within('#outdoor-temp-forecast-chart') do
      expect(page).to have_css('canvas')
    end
  end

  it 'switches between today and tomorrow and all days' do
    visit '/forecast'

    within('#forecast-timeframe') { find('a[data-nav=next]').click }

    expect(page).to have_current_path('/forecast/all')
    expect(page).to have_text('Die nächsten 3 Tage')

    within('#forecast-timeframe') { find('a[data-nav=prev]').click }

    expect(page).to have_current_path('/forecast')
    expect(page).to have_text('Heute und morgen')
  end

  it 'navigates to day view from forecast page' do
    visit '/forecast'

    # Find and click the "TAG" link
    first('a', text: 'TAG').click

    expect(page).to have_current_path('/inverter_power/day')
    expect(page).to have_css('#stats-day')
  end
end
