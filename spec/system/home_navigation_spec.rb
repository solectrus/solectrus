describe 'Home page' do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.local(2022, 6, 21, 12, 0, 0) }

  %w[
    inverter_power
    inverter_power_1
    inverter_power_2
    battery_power
    grid_power
    autarky
    self_consumption
    house_power
    heatpump_power
    wallbox_power
    case_temp
    battery_soc
    car_battery_soc
    co2_reduction
  ].each do |path|
    it "#{path} is clickable" do # rubocop:disable RSpec/NoExpectationExample
      visit "/#{path}"

      navigate_now(path)
      navigate_day(path)
      navigate_24_hours(path)
      navigate_week(path)
      navigate_month(path)
      navigate_year(path)
      navigate_all(path)
    end
  end

  private

  def navigate_now(path)
    expect(page).to have_css('#stats-now')
    expect(page).to have_current_path("/#{path}/now")
    expect(page.title).to include('Live')
    expect(page).to have_content('12:00 Uhr')

    if path == 'inverter_power'
      expect(page).to have_content(/\d+,\d+ kW/) # Match power values like "10,0 kW"
    end

    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#balance-chart-now')
  end

  def navigate_day(path)
    click_on 'Tag'
    expect(page).to have_css('#stats-day')
    expect(page).to have_current_path("/#{path}/2022-06-21")
    expect(page.title).to include('Dienstag, 21. Juni 2022')
    expect(page).to have_content('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')

    if path == 'inverter_power'
      expect(page).to have_css('#segment-inverter_power')
      within('#segment-inverter_power') do
        expect(page).to have_content(/\d+,\d+\s*kWh/) # Flexible energy value
      end
      expect(page).to have_css('#balance-chart-2022-06-21')
      within('#balance-chart-2022-06-21') do
        expect(page).to have_content('Erwartet werden')
        expect(page).to have_content(/\d+/) # Any number for forecast
        expect(page).to have_content('kWh')
      end
    end

    click_prev_and_expect('Montag, 20. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#balance-chart-2022-06-20')
    within('#balance-chart-2022-06-20') do
      expect(page).to have_content('Keine Daten vorhanden')
    end

    click_next_and_expect('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')
  end

  def navigate_24_hours(path)
    click_on 'Tag'
    expect(page).to have_css('#stats-hours')
    expect(page).to have_current_path("/#{path}/P24H")
    expect(page.title).to include('Letzte 24 Stunden')
    expect(page).to have_content('Letzte 24 Stunden')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-hours')

    return unless path == 'inverter_power'

    expect(page).to have_content(/\d+(?:,\d+)?\s*[MkGT]?Wh/) # Match energy values
  end

  def navigate_week(path)
    click_on 'Woche'
    expect(page).to have_css('#stats-week')
    expect(page).to have_current_path("/#{path}/2022-W25")
    expect(page.title).to include('KW 25, 2022')
    expect(page).to have_content('KW 25, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-week')

    if path == 'inverter_power'
      expect(page).to have_content(/\d+(?:,\d+)?\s*[MkGT]?Wh/) # Match energy values
    end

    click_prev_and_expect('KW 24, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#balance-chart-2022-W24')
    within('#balance-chart-2022-W24') do
      expect(page).to have_content('Keine Daten vorhanden')
    end

    click_next_and_expect('KW 25, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-week')
  end

  def navigate_month(path)
    click_on 'Monat'
    expect(page).to have_css('#stats-month')
    expect(page).to have_current_path("/#{path}/2022-06")
    expect(page.title).to include('Juni 2022')
    expect(page).to have_content('Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-month')

    if path == 'inverter_power'
      expect(page).to have_content(/\d+(?:,\d+)?\s*[MkGT]?Wh/) # Match energy values
    end

    click_prev_and_expect('Mai 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#balance-chart-2022-05')
    within('#balance-chart-2022-05') do
      expect(page).to have_content('Keine Daten vorhanden')
    end

    click_next_and_expect('Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-month')
  end

  def navigate_year(path)
    click_on 'Jahr'
    expect(page).to have_css('#stats-year')
    expect(page).to have_current_path("/#{path}/2022")
    expect(page.title).to include('2022')
    expect(page).to have_content('2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-year')

    if path == 'inverter_power'
      expect(page).to have_content(/\d+(?:,\d+)?\s*[MkGT]?Wh/) # Match energy values
    end

    click_prev_and_expect('2021')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#balance-chart-2021')
    within('#balance-chart-2021') do
      expect(page).to have_content('Keine Daten vorhanden')
    end

    click_next_and_expect('2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-year')
  end

  def navigate_all(path)
    click_on 'Gesamt'
    expect(page).to have_css('#stats-all')
    expect(page).to have_current_path("/#{path}/all")
    expect(page.title).to include('Seit Inbetriebnahme')
    expect(page).to have_content('Seit Inbetriebnahme')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-all')

    return unless path == 'inverter_power'

    expect(page).to have_content(/\d+(?:,\d+)?\s*[MkGT]?Wh/) # Match energy values
  end

  def click_prev_and_expect(expected_time)
    turbo_safe_click('Zurück')

    within('header time') { expect(page).to have_content(expected_time) }
  end

  def click_next_and_expect(expected_time)
    turbo_safe_click('Weiter')

    within('header time') { expect(page).to have_content(expected_time) }
  end
end
