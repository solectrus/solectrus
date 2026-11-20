describe 'Heatpump navigation' do
  include ActiveSupport::Testing::TimeHelpers

  before { stub_feature(:power_splitter, :heatpump, :trends) }

  %w[heatpump_heating_power heatpump_cop outdoor_temp].each do |path|
    context "when #{path}" do
      it 'navigates through all time periods' do # rubocop:disable RSpec/NoExpectationExample
        visit "/heatpump/#{path}"

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
    expect(page).to have_current_path("/heatpump/#{path}/now")
    expect(page.title).to include('Aktuell')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-now')

    check_top10_link(path)
  end

  def navigate_day(path)
    click_on 'Tag'

    expect(page).to have_css('#stats-day')
    expect(page).to have_current_path("/heatpump/#{path}/2022-06-21")
    expect(page.title).to include('Dienstag, 21. Juni 2022')
    expect(page).to have_text('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')

    click_prev_and_expect('Montag, 20. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#heatpump-chart-2022-06-20')

    click_next_and_expect('Dienstag, 21. Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-day')

    check_no_insights
    check_top10_link(path)
  end

  def navigate_week(path)
    click_on 'Woche'

    expect(page).to have_css('#stats-week')
    expect(page).to have_current_path("/heatpump/#{path}/2022-W25")
    expect(page.title).to include('KW 25, 2022')
    expect(page).to have_text('KW 25, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-week')

    click_prev_and_expect('KW 24, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#heatpump-chart-2022-W24')

    click_next_and_expect('KW 25, 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-week')

    check_no_insights
    check_top10_link(path)
  end

  def navigate_month(path)
    click_on 'Monat'

    expect(page).to have_css('#stats-month')
    expect(page).to have_current_path("/heatpump/#{path}/2022-06")
    expect(page.title).to include('Juni 2022')
    expect(page).to have_text('Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-month')
    check_insights(path)

    click_prev_and_expect('Mai 2022')

    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#heatpump-chart-2022-05')

    click_next_and_expect('Juni 2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-month')

    check_top10_link(path)
  end

  def navigate_year(path)
    click_on 'Jahr'

    expect(page).to have_css('#stats-year')
    expect(page).to have_current_path("/heatpump/#{path}/2022")
    expect(page.title).to include('2022')
    expect(page).to have_text('2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-year')
    check_insights(path)

    click_prev_and_expect('2021')

    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#heatpump-chart-2021')

    click_next_and_expect('2022')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-year')

    check_top10_link(path)
  end

  def navigate_all(path)
    click_on 'Gesamt'

    expect(page).to have_css('#stats-all')
    expect(page).to have_current_path("/heatpump/#{path}/all")
    expect(page.title).to include('Seit Inbetriebnahme')
    expect(page).to have_text('Seit Inbetriebnahme')
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
    expect(page).to have_css('#chart-all')
    check_insights(path)

    check_top10_link(path)
  end

  def click_prev_and_expect(expected_time)
    turbo_safe_click('Zurück')

    within('header time') { expect(page).to have_text(expected_time) }
  end

  def click_next_and_expect(expected_time)
    turbo_safe_click('Weiter')

    within('header time') { expect(page).to have_text(expected_time) }
  end

  def check_top10_link(path)
    within '#primary-nav-desktop' do
      top10_link = find('a[href*="/top10/"]')
      expect(top10_link[:href]).to include(path)
    end
  end

  # A day and a week have no insights beside the timeframe
  def check_no_insights
    expect(page).to have_no_css('[data-trends-button]')
  end

  def check_insights(_path)
    # The button beside the timeframe, for a month or a year the trends
    find('[data-trends-button]').click
    expect(page).to have_css('dialog#modal-sheet[open]')

    click_on('Schließen')
    expect(page).to have_no_css('dialog#modal-sheet[open]')
  end
end
