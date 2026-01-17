describe 'House navigation' do
  include ActiveSupport::Testing::TimeHelpers

  before { stub_feature(:power_splitter, :custom_consumer, :insights) }

  %w[house_power house_power_without_custom custom_power_01].each do |path|
    context "when #{path}" do
      it 'navigates through all time periods' do # rubocop:disable RSpec/NoExpectationExample
        visit "/house/#{path}"

        navigate_now(path)
        navigate_day(path)
        navigate_week(path)
        navigate_month(path)
        navigate_year(path)
        navigate_all(path)
      end
    end
  end

  it 'loads charts when clicking a segment' do
    visit '/house/house_power/now'

    expect(page).to have_css('#house-chart-now')
    expect(page).to have_css('#segment-house_power_without_custom')

    find_by_id('segment-house_power_without_custom').click

    expect(page).to have_current_path('/house/house_power_without_custom/now')
    expect(page).to have_css(
      '#house-chart-now[src*="/house/charts/house_power_without_custom/now"]',
    )

    within('#house-chart-now') do
      expect(page).to have_css(
        'select[name="sensor-selector"] option[selected][value*="/house/house_power_without_custom/now"]',
        visible: :all,
      )
    end
  end

  private

  def navigate_now(path)
    expect(page).to have_css('#stats-now')
    expect(page).to have_current_path("/house/#{path}/now")
    expect(page.title).to include('Live')
    expect(page).to have_content('12:00 Uhr')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-now')

    return unless path == 'house_power'

    expect(page).to have_css('#segment-house_power_without_custom')
    within('#segment-house_power_without_custom') do
      expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
    end
  end

  def navigate_day(path)
    click_on 'Tag'

    expect(page).to have_css('#stats-day')
    expect(page).to have_current_path("/house/#{path}/2022-06-21")
    expect(page.title).to include('Dienstag, 21. Juni 2022')
    expect(page).to have_content('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')

    if path == 'house_power'
      expect(page).to have_css('#segment-house_power_without_custom')
      within('#segment-house_power_without_custom') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    check_insights(path)

    click_prev_and_expect('Montag, 20. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#house-chart-2022-06-20')

    click_next_and_expect('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')

    check_top10_link(path)
  end

  def navigate_week(path)
    click_on 'Woche'

    expect(page).to have_css('#stats-week')
    expect(page).to have_current_path("/house/#{path}/2022-W25")
    expect(page.title).to include('KW 25, 2022')
    expect(page).to have_content('KW 25, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-week')

    if path == 'house_power'
      expect(page).to have_css('#segment-house_power_without_custom')
      within('#segment-house_power_without_custom') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    check_insights(path)

    click_prev_and_expect('KW 24, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#house-chart-2022-W24')

    click_next_and_expect('KW 25, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-week')

    check_top10_link(path)
  end

  def navigate_month(path)
    click_on 'Monat'

    expect(page).to have_css('#stats-month')
    expect(page).to have_current_path("/house/#{path}/2022-06")
    expect(page.title).to include('Juni 2022')
    expect(page).to have_content('Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-month')

    if path == 'house_power'
      expect(page).to have_css('#segment-house_power_without_custom')
      within('#segment-house_power_without_custom') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    check_insights(path)

    click_prev_and_expect('Mai 2022')

    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#house-chart-2022-05')

    click_next_and_expect('Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-month')

    check_top10_link(path)
  end

  def navigate_year(path)
    click_on 'Jahr'

    expect(page).to have_css('#stats-year')
    expect(page).to have_current_path("/house/#{path}/2022")
    expect(page.title).to include('2022')
    expect(page).to have_content('2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-year')

    if path == 'house_power'
      expect(page).to have_css('#segment-house_power_without_custom')
      within('#segment-house_power_without_custom') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    check_insights(path)

    click_prev_and_expect('2021')

    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#house-chart-2021')

    click_next_and_expect('2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-year')

    check_top10_link(path)
  end

  def navigate_all(path)
    click_on 'Gesamt'

    expect(page).to have_css('#stats-all')
    expect(page).to have_current_path("/house/#{path}/all")
    expect(page.title).to include('Seit Inbetriebnahme')
    expect(page).to have_content('Seit Inbetriebnahme')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-all')

    if path == 'house_power'
      expect(page).to have_css('#segment-house_power_without_custom')
      within('#segment-house_power_without_custom') do
        expect(page).to have_content(/\d+(?:,\d+)? [MkWh]+/) # Match kWh or MWh values
      end
    end

    check_insights(path)
    check_top10_link(path)
  end

  def click_prev_and_expect(expected_time)
    turbo_safe_click('Zurück')

    within('header time') { expect(page).to have_content(expected_time) }
  end

  def click_next_and_expect(expected_time)
    turbo_safe_click('Weiter')

    within('header time') { expect(page).to have_content(expected_time) }
  end

  def check_top10_link(path)
    return if path == 'house_power_without_custom'

    within '#primary-nav-desktop' do
      top10_link = find('a[href*="/top10/"]')
      expect(top10_link[:href]).to include(path)
    end
  end

  def check_insights(path)
    return if path == 'house_power_without_custom'

    click_on('Kennzahlen & Trend')
    expect(page).to have_css('#modal-title')

    click_on('Schließen')
    expect(page).to have_no_css('#modal-title')
  end
end
