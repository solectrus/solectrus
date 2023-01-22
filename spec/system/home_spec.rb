describe 'Home', js: true, vcr: { cassette_name: 'version' } do
  before do
    Price.electricity.create! starts_at:
                                Rails.configuration.x.installation_date,
                              value: 0.20
    Price.feed_in.create! starts_at: Rails.configuration.x.installation_date,
                          value: 0.08

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

  Senec::FIELDS_COMBINED.each do |field|
    it "presents data and allows navigation for #{field}" do
      visit "/#{field}"
      expect(page).to have_text(I18n.t('layout.stats').upcase)
      expect(page).to have_css('#chart-now')
      navigate_days

      click_on I18n.t('calculator.now')
      expect(page).to have_css('#tab-now')
      navigate_weeks

      click_on I18n.t('calculator.now')
      expect(page).to have_css('#tab-now')
      navigate_months

      click_on I18n.t('calculator.now')
      expect(page).to have_css('#tab-now')
      navigate_years

      navigate_all
      navigate_now
    end
  end

  private

  def navigate_now
    click_on I18n.t('calculator.now')
    expect(page).to have_css('#tab-now')

    expect(page).to have_text('5,0 kW')
    expect(page).to have_text('0,4 kW')
    expect(page).to have_text('2,5 kW')
    expect(page).to have_text('10,0 kW')
    expect(page).to have_text('8,0 kW')

    expect(page).to have_css("[data-controller='stats-with-chart--component']")
  end

  def navigate_days
    click_on I18n.t('calculator.day')
    expect(page).to have_css('#tab-day')
    expect_time(Date.current, '%Y-%m-%d')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")

    click_prev
    expect(page).to have_css('#tab-day')
    expect_time(Date.yesterday, '%Y-%m-%d')
    expect(page).not_to have_css(
      "[data-controller='stats-with-chart--component']",
    )

    click_next
    expect(page).to have_css('#tab-day')
    expect_time(Date.current, '%Y-%m-%d')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")
  end

  def navigate_weeks
    click_on I18n.t('calculator.week')
    expect(page).to have_css('#tab-week')
    expect_time(Date.current, '%G-W%V')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")

    click_prev
    expect(page).to have_css('#tab-week')
    expect_time(1.week.ago, '%G-W%V')
    expect(page).not_to have_css(
      "[data-controller='stats-with-chart--component']",
    )

    click_next
    expect(page).to have_css('#tab-week')
    expect_time(Date.current, '%G-W%V')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")
  end

  def navigate_months
    click_on I18n.t('calculator.month')
    expect(page).to have_css('#tab-month')
    expect_time(Date.current, '%Y-%m')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")

    click_prev
    expect(page).to have_css('#tab-month')
    expect_time(1.month.ago, '%Y-%m')
    expect(page).not_to have_css(
      "[data-controller='stats-with-chart--component']",
    )

    click_next
    expect(page).to have_css('#tab-month')
    expect_time(Date.current, '%Y-%m')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")
  end

  def navigate_years
    click_on I18n.t('calculator.year')
    expect(page).to have_css('#tab-year')
    expect_time(Date.current, '%Y')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")

    click_prev
    expect(page).to have_css('#tab-year')
    expect_time(1.year.ago, '%Y')
    expect(page).not_to have_css(
      "[data-controller='stats-with-chart--component']",
    )

    click_next
    expect(page).to have_css('#tab-year')
    expect_time(Date.current, '%Y')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")
  end

  def navigate_all
    click_on I18n.t('calculator.all')
    expect(page).to have_css('#tab-all')

    expect(page).not_to have_xpath('.//a[contains(@rel, \'prev\')]')
    expect(page).not_to have_xpath('.//a[contains(@rel, \'next\')]')
    expect(page).to have_css("[data-controller='stats-with-chart--component']")
  end

  def click_prev
    button_xpath = './/a[contains(@rel, \'prev\')]'
    expect(page).to have_xpath(button_xpath)
    find(:xpath, button_xpath).click
  end

  def click_next
    button_xpath = './/a[contains(@rel, \'next\')]'
    expect(page).to have_xpath(button_xpath)
    find(:xpath, button_xpath).click
  end

  def expect_time(time, format)
    expect(page).to have_css("time[datetime='#{time.strftime(format)}']")
  end
end
