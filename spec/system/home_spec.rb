describe 'Home', type: :system, js: true, vcr: true do
  it 'shows values' do
    visit '/'

    click_on 'Jetzt'
    expect(page).to have_text('kW', count: 4)

    click_on 'Letzte 24 Stunden'
    expect(page).to have_text('kWh', count: 4)

    click_on 'Letzte 7 Tage'
    expect(page).to have_text('kWh', count: 4)

    click_on 'Letzte 30 Tage'
    expect(page).to have_text('kWh', count: 4)
  end
end
