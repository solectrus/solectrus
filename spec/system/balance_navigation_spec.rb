describe 'Balance page' do
  include ActiveSupport::Testing::TimeHelpers

  before do
    stub_feature(
      :relative_timeframe,
      :power_splitter,
      :insights,
      :finance_charts,
      :car,
    )
  end

  %w[
    inverter_power
    inverter_power_1
    inverter_power_2
    battery_power
    grid_power
    autarky
    self_consumption_quote
    house_power
    heatpump_power
    wallbox_power
    case_temp
    battery_soc
    car_battery_soc
    co2_reduction
    grid_costs
    savings
    grid_revenue
  ].each do |path|
    context "when #{path}" do
      it 'navigates through all time periods' do # rubocop:disable RSpec/NoExpectationExample
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

    check_top10_link(path)
  end

  def navigate_day(path)
    click_on 'Tag'
    expect(page).to have_css('#stats-day')
    expect(page).to have_current_path("/#{path}/2022-06-21")
    expect(page.title).to include('Dienstag, 21. Juni 2022')
    expect(page).to have_content('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")

    expect(page).to have_css('#chart-day')
    check_inverter_power_specifics(path)
    check_insights(path) unless finance_sensor?(path)
    check_top10_link(path)

    click_prev_and_expect('Montag, 20. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect_chart_or_blank(
      path,
      '#balance-chart-2022-06-20',
      'Keine Daten vorhanden',
    )

    click_next_and_expect('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')
  end

  def navigate_24_hours(path)
    click_on('Tag') # Second click to open 24H view

    expect(page).to have_css('#stats-hours')
    expect(page).to have_current_path("/#{path}/P24H")
    expect(page.title).to include('Letzte 24 Stunden')
    expect(page).to have_content('Letzte 24 Stunden')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")

    expect(page).to have_css('#chart-hours')
    check_top10_link(path)

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

    check_insights(path)
    check_top10_link(path)

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

    check_insights(path)
    check_top10_link(path)

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

    check_insights(path)
    check_top10_link(path)

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

    check_insights(path)
    check_top10_link(path)

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

  def check_insights(path)
    if path.in? %w[
                  autarky
                  self_consumption_quote
                  battery_soc
                  car_battery_soc
                  co2_reduction
                ]
      return
    end

    click_on('Kennzahlen & Trend')
    expect(page).to have_css('#modal-title')

    click_on('Schließen')
    expect(page).to have_no_css('#modal-title')
  end

  def finance_sensor?(path)
    path.in?(%w[grid_costs savings grid_revenue])
  end

  def expect_chart_or_blank(_path, chart_id, blank_message = nil)
    if blank_message
      # When blank, there's no chart element - just the message
      expect(page).to have_content(blank_message)
    else
      expect(page).to have_css(chart_id)
    end
  end

  def check_inverter_power_specifics(path)
    return unless path == 'inverter_power'

    expect(page).to have_css('#segment-inverter_power')
    within('#segment-inverter_power') do
      expect(page).to have_content(/\d+,\d+\s*kWh/)
    end
    expect(page).to have_css('#balance-chart-2022-06-21')
    within('#balance-chart-2022-06-21') do
      expect(page).to have_content('Erwartet werden')
      expect(page).to have_content(/\d+/)
      expect(page).to have_content('kWh')
    end
  end

  def check_top10_link(path)
    # Only check for sensors that are in top10
    unless path.in?(
             %w[
               inverter_power
               house_power
               grid_import_power
               grid_export_power
               battery_discharging_power
               battery_charging_power
               wallbox_power
               heatpump_power
               co2_reduction
             ],
           )
      return
    end

    within '#primary-nav-desktop' do
      top10_link = find('a[href*="/top10/"]')
      expect(top10_link[:href]).to include(path)
    end
  end
end
