describe 'Home', type: :system, js: true do
  before do
    add_influx_point(
      name: 'SENEC',
      fields: {
        inverter_power: 4_000,
        house_power: 500,
        bat_power_plus: 0,
        bat_power_minus: 0,
        bat_fuel_charge: 40.0,
        wallbox_charge_power: 0,
        grid_power_plus: 0,
        grid_power_minus: 3_500,
      },
      time: 1.hour.ago,
    )

    add_influx_point(
      name: 'Forecast',
      fields: {
        watt: 4_000,
      },
      time: 1.hour.ago,
    )

    add_influx_point(
      name: 'SENEC',
      fields: {
        inverter_power: 5_000,
        house_power: 430,
        bat_power_plus: 2_500,
        bat_power_minus: 0,
        bat_fuel_charge: 56.3,
        wallbox_charge_power: 10_000,
        grid_power_plus: 8_000,
        grid_power_minus: 0,
      },
    )

    add_influx_point(name: 'Forecast', fields: { watt: 6_000 })
  end

  it 'presents data and allows navigation' do
    visit '/'
    expect(page).to have_text(I18n.t('layout.stats').upcase)

    navigate_days
    navigate_now

    navigate_weeks
    navigate_now

    navigate_months
    navigate_now

    navigate_years
    navigate_now

    navigate_all
    navigate_now
  end

  private

  def navigate_now
    click_on I18n.t('calculator.now')
    expect(page).to have_css('#tab-now')

    expect(page).to have_text('5,0 kW')
    expect(page).to have_text('0,4 kW')
    expect(page).to have_text('2,5 kW')
    expect(page).to have_text('56,3 %')
    expect(page).to have_text('10,0 kW')
    expect(page).to have_text('8,0 kW')
  end

  def navigate_days
    click_on I18n.t('calculator.day')
    expect(page).to have_css('#tab-day')
    expect(page).to have_css('#chart-day')

    find(:xpath, ".//a[contains(@rel, 'prev')]").click
    expect(page).to have_css('#tab-day')
    expect(page).to have_css('#chart-day')

    find(:xpath, ".//a[contains(@rel, 'next')]").click
    expect(page).to have_css('#tab-day')
    expect(page).to have_css('#chart-day')
  end

  def navigate_weeks
    click_on I18n.t('calculator.week')
    expect(page).to have_css('#tab-week')
    expect(page).to have_css('#chart-week')

    find(:xpath, ".//a[contains(@rel, 'prev')]").click
    expect(page).to have_css('#tab-week')
    expect(page).to have_css('#chart-week')

    find(:xpath, ".//a[contains(@rel, 'next')]").click
    expect(page).to have_css('#tab-week')
    expect(page).to have_css('#chart-week')
  end

  def navigate_months
    click_on I18n.t('calculator.month')
    expect(page).to have_css('#tab-month')
    expect(page).to have_css('#chart-month')

    find(:xpath, ".//a[contains(@rel, 'prev')]").click
    expect(page).to have_css('#tab-month')
    expect(page).to have_css('#chart-month')

    find(:xpath, ".//a[contains(@rel, 'next')]").click
    expect(page).to have_css('#tab-month')
    expect(page).to have_css('#chart-month')
  end

  def navigate_years
    click_on I18n.t('calculator.year')
    expect(page).to have_css('#tab-year')
    expect(page).to have_css('#chart-year')

    find(:xpath, ".//a[contains(@rel, 'prev')]").click
    expect(page).to have_css('#tab-year')
    expect(page).to have_css('#chart-year')

    find(:xpath, ".//a[contains(@rel, 'next')]").click
    expect(page).to have_css('#tab-year')
    expect(page).to have_css('#chart-year')
  end

  def navigate_all
    click_on I18n.t('calculator.all')
    expect(page).to have_css('#tab-all')
  end
end
