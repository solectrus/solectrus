describe 'Inverter navigation' do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.local(2022, 6, 21, 12, 0, 0) }

  %w[inverter_power].each do |path|
    context "when #{path}" do
      it 'allows complete navigation through all time periods' do # rubocop:disable RSpec/NoExpectationExample
        visit "/inverter/#{path}"

        navigate_now(path)
        navigate_day(path)
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
    expect(page).to have_current_path("/inverter/#{path}/now")
    expect(page.title).to include('Live')
    expect(page).to have_content('12:00 Uhr')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-now')

    return unless path == 'inverter_power'

    expect(page).to have_css('#segment-inverter_power_1')
    within('#segment-inverter_power_1') do
      expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
    end
  end

  def navigate_day(path)
    click_on 'Tag'

    expect(page).to have_css('#stats-day')
    expect(page).to have_current_path("/inverter/#{path}/2022-06-21")
    expect(page.title).to include('Dienstag, 21. Juni 2022')
    expect(page).to have_content('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')

    if path == 'inverter_power'
      expect(page).to have_css('#segment-inverter_power_1')
      within('#segment-inverter_power_1') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    click_prev_and_expect('Montag, 20. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#inverter-chart-2022-06-20')
    within('#inverter-chart-2022-06-20') do
      expect(page).to have_content('Erzeugung') # Has data due to comprehensive seeding
    end

    click_next_and_expect('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')
  end

  def navigate_week(path)
    click_on 'Woche'

    expect(page).to have_css('#stats-week')
    expect(page).to have_current_path("/inverter/#{path}/2022-W25")
    expect(page.title).to include('KW 25, 2022')
    expect(page).to have_content('KW 25, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-week')

    if path == 'inverter_power'
      expect(page).to have_css('#segment-inverter_power_1')
      within('#segment-inverter_power_1') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    click_prev_and_expect('KW 24, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#inverter-chart-2022-W24')
    within('#inverter-chart-2022-W24') do
      expect(page).to have_content('Erzeugung') # Has data due to comprehensive seeding
    end

    click_next_and_expect('KW 25, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-week')
  end

  def navigate_month(path)
    click_on 'Monat'

    expect(page).to have_css('#stats-month')
    expect(page).to have_current_path("/inverter/#{path}/2022-06")
    expect(page.title).to include('Juni 2022')
    expect(page).to have_content('Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-month')

    if path == 'inverter_power'
      expect(page).to have_css('#segment-inverter_power_1')
      within('#segment-inverter_power_1') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    click_prev_and_expect('Mai 2022')

    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#inverter-chart-2022-05')
    within('#inverter-chart-2022-05') do
      expect(page).to have_content('Erzeugung') # Has data due to comprehensive seeding
    end

    click_next_and_expect('Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-month')
  end

  def navigate_year(path)
    click_on 'Jahr'

    expect(page).to have_css('#stats-year')
    expect(page).to have_current_path("/inverter/#{path}/2022")
    expect(page.title).to include('2022')
    expect(page).to have_content('2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-year')

    if path == 'inverter_power'
      expect(page).to have_css('#segment-inverter_power_1')
      within('#segment-inverter_power_1') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    click_prev_and_expect('2021')

    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#inverter-chart-2021')
    within('#inverter-chart-2021') do
      expect(page).to have_content('Erzeugung') # Has data due to comprehensive seeding
    end

    click_next_and_expect('2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-year')
  end

  def navigate_all(path)
    click_on 'Gesamt'

    expect(page).to have_css('#stats-all')
    expect(page).to have_current_path("/inverter/#{path}/all")
    expect(page.title).to include('Seit Inbetriebnahme')
    expect(page).to have_content('Seit Inbetriebnahme')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-all')

    return unless path == 'inverter_power'

    expect(page).to have_css('#segment-inverter_power_1')
    within('#segment-inverter_power_1') do
      expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
    end
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
