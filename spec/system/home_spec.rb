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

    add_influx_point(
      'Forecast',
      {
        watt: 6_000
      }
    )
  end

  it 'presents data and allows navigation' do
    visit '/'
    expect(page).to have_text('Dashboard')

    navigate_now
    navigate_days

    navigate_now
    navigate_weeks

    navigate_now
    navigate_months

    navigate_now
    navigate_years

    navigate_now
    navigate_all
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

    find(:xpath, ".//a[contains(@rel, 'next')]").click
    expect(page).to have_css('#tab-day')

    find(:xpath, ".//a[contains(@rel, 'prev')]").click
    expect(page).to have_css('#tab-day')
  end

  def navigate_weeks
    click_on I18n.t('calculator.week')
    expect(page).to have_css('#tab-week')

    find(:xpath, ".//a[contains(@rel, 'next')]").click
    expect(page).to have_css('#tab-week')

    find(:xpath, ".//a[contains(@rel, 'prev')]").click
    expect(page).to have_css('#tab-week')
  end

  def navigate_months
    click_on I18n.t('calculator.month')
    expect(page).to have_css('#tab-month')

    find(:xpath, ".//a[contains(@rel, 'next')]").click
    expect(page).to have_css('#tab-month')

    find(:xpath, ".//a[contains(@rel, 'prev')]").click
    expect(page).to have_css('#tab-month')
  end

  def navigate_years
    click_on I18n.t('calculator.year')
    expect(page).to have_css('#tab-year')

    find(:xpath, ".//a[contains(@rel, 'next')]").click
    expect(page).to have_css('#tab-year')

    find(:xpath, ".//a[contains(@rel, 'prev')]").click
    expect(page).to have_css('#tab-year')
  end

  def navigate_all
    click_on I18n.t('calculator.all')
    expect(page).to have_css('#tab-all')
  end
end
