shared_examples_for 'balance navigation' do |paths|
  before do
    stub_feature(
      :relative_timeframe,
      :power_splitter,
      :insights,
      :finance_charts,
      :car,
    )
  end

  paths.each do |path|
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
    expect_timeframe_page(path, stats_id: 'now', expected_path: 'now', title: 'Live', content: '12:00 Uhr')

    if path == 'inverter_power'
      expect(page).to have_content(/\d+,\d+ kW/) # Match power values like "10,0 kW"
    end

    expect(page).to have_css('#balance-chart-now')

    check_top10_link(path)
  end

  def navigate_day(path)
    click_on 'Tag'
    expect_timeframe_page(path, stats_id: 'day', expected_path: '2022-06-21', title: 'Dienstag, 21. Juni 2022')

    expect(page).to have_css('#chart-day')
    check_inverter_power_specifics(path)
    check_insights(path) unless finance_sensor?(path)
    check_top10_link(path)

    check_prev_next(
      prev_text: 'Montag, 20. Juni 2022',
      back_text: 'Dienstag, 21. Juni 2022',
      chart_id: '#chart-day',
    )
  end

  def navigate_24_hours(path)
    click_on('Tag') # Second click to open 24H view

    expect_timeframe_page(path, stats_id: 'hours', expected_path: 'P24H', title: 'Letzte 24 Stunden')

    expect(page).to have_css('#chart-hours')
    check_top10_link(path)

    return unless path == 'inverter_power'

    expect(page).to have_content(/\d+(?:,\d+)?\s*[MkGT]?Wh/) # Match energy values
  end

  def navigate_week(path)
    click_on 'Woche'
    expect_timeframe_page(path, stats_id: 'week', expected_path: '2022-W25', title: 'KW 25, 2022')
    expect(page).to have_css('#chart-week')

    check_inverter_power_energy_values(path)
    check_insights(path)
    check_top10_link(path)

    check_prev_next(
      prev_text: 'KW 24, 2022',
      prev_chart_id: '#balance-chart-2022-W24',
      back_text: 'KW 25, 2022',
      chart_id: '#chart-week',
    )
  end

  def navigate_month(path)
    click_on 'Monat'
    expect_timeframe_page(path, stats_id: 'month', expected_path: '2022-06', title: 'Juni 2022')
    expect(page).to have_css('#chart-month')

    check_inverter_power_energy_values(path)
    check_insights(path)
    check_top10_link(path)

    check_prev_next(
      prev_text: 'Mai 2022',
      prev_chart_id: '#balance-chart-2022-05',
      back_text: 'Juni 2022',
      chart_id: '#chart-month',
    )
  end

  def navigate_year(path)
    click_on 'Jahr'
    expect_timeframe_page(path, stats_id: 'year', expected_path: '2022', title: '2022')
    expect(page).to have_css('#chart-year')

    check_inverter_power_energy_values(path)
    check_insights(path)
    check_top10_link(path)

    check_prev_next(
      prev_text: '2021',
      prev_chart_id: '#balance-chart-2021',
      back_text: '2022',
      chart_id: '#chart-year',
    )
  end

  def navigate_all(path)
    click_on 'Gesamt'
    expect_timeframe_page(path, stats_id: 'all', expected_path: 'all', title: 'Seit Inbetriebnahme')
    expect(page).to have_css('#chart-all')

    check_insights(path)
    check_top10_link(path)

    return unless path == 'inverter_power'

    expect(page).to have_content(/\d+(?:,\d+)?\s*[MkGT]?Wh/) # Match energy values
  end

  def expect_timeframe_page(path, stats_id:, expected_path:, title:, content: title)
    expect(page).to have_css("#stats-#{stats_id}")
    expect(page).to have_current_path("/#{path}/#{expected_path}")
    expect(page.title).to include(title)
    expect(page).to have_content(content)
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
  end

  def check_prev_next(prev_text:, back_text:, chart_id:, prev_chart_id: nil)
    click_prev_and_expect(prev_text)
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")

    if prev_chart_id
      within(prev_chart_id) do
        expect(page).to have_content('Keine Daten vorhanden')
      end
    else
      expect(page).to have_content('Keine Daten vorhanden')
    end

    click_next_and_expect(back_text)
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css(chart_id)
  end

  def click_prev_and_expect(expected_time)
    turbo_safe_click('Zurück')

    within('header time') { expect(page).to have_content(expected_time) }
  end

  def click_next_and_expect(expected_time)
    turbo_safe_click('Weiter')

    within('header time') { expect(page).to have_content(expected_time) }
  end

  def check_inverter_power_energy_values(path)
    return unless path == 'inverter_power'

    expect(page).to have_content(/\d+(?:,\d+)?\s*[MkGT]?Wh/) # Match energy values
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
