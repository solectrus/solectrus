describe 'Home', type: :system, js: true, vcr: true do
  it 'shows values' do
    visit '/'

    click_on I18n.t('calculator.current')
    expect(page).to have_text('kW', count: 5)
    expect(page).to have_text('%', count: 1)

    click_on I18n.t('calculator.day')
    expect(page).to have_css('svg')
    expect(page).to have_text('kWh', count: 4)

    click_on I18n.t('calculator.week')
    expect(page).to have_css('svg')
    expect(page).to have_text('kWh', count: 4)

    click_on I18n.t('calculator.month')
    expect(page).to have_css('svg')
    expect(page).to have_text('kWh', count: 4)

    click_on I18n.t('calculator.year')
    expect(page).to have_css('svg')
    expect(page).to have_text('kWh', count: 4)

    click_on I18n.t('calculator.all')
    expect(page).to have_css('svg')
    expect(page).to have_text('kWh', count: 4)
  end
end
