describe 'Home', type: :system, js: true do
  before do
    add_influx_point(
      'SENEC',
      {
        inverter_power:       5_000,
        house_power:          430,
        bat_power_plus:       2_500,
        bat_power_minus:      0,
        bat_fuel_charge:      56.3,
        wallbox_charge_power: 10_000,
        grid_power_plus:      8_000,
        grid_power_minus:     0
      }
    )
  end

  it 'shows values' do
    visit '/'

    click_on I18n.t('calculator.now')
    expect(page).to have_css('#tab-now')

    expect(page).to have_text('5,0 kW')
    expect(page).to have_text('0,4 kW')
    expect(page).to have_text('2,5 kW')
    expect(page).to have_text('56,3 %')
    expect(page).to have_text('10,0 kW')
    expect(page).to have_text('8,0 kW')

    click_on I18n.t('calculator.day')
    expect(page).to have_css('#tab-day')

    click_on I18n.t('calculator.week')
    expect(page).to have_css('#tab-week')

    click_on I18n.t('calculator.month')
    expect(page).to have_css('#tab-month')

    click_on I18n.t('calculator.year')
    expect(page).to have_css('#tab-year')

    click_on I18n.t('calculator.all')
    expect(page).to have_css('#tab-all')
  end
end
