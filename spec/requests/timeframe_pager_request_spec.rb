# The period of a phone at the top of the content, between its arrows (see
# TimeframePager)
describe 'Timeframe pager' do
  before { travel_to Time.zone.local(2026, 10, 23, 12) }

  def pager = response.parsed_body.at_css('nav[aria-label="Timeframe"]')

  def period = pager.at_css('a[aria-haspopup="dialog"]')

  def arrows = pager.css('a[data-nav]').map { URI(it['href']).path }

  it 'names the period of the page and opens the sheet from it' do
    get '/inverter_power/2026-10'

    expect(period.text.squish).to eq('October 2026')
    expect(period['data-turbo-frame']).to eq('modal')
    expect(period['href']).to end_with('/inverter_power/2026-10?select=1')
  end

  it 'names a day with its date' do
    get '/inverter_power/day'

    expect(period.text.squish).to eq(Timeframe.day.localized)
  end

  # The menu of the tab picks the comparison, and there is nothing to turn
  it 'shows no period on a comparison of the years' do
    get '/inverter_power/all/by_month'

    expect(pager['class']).to eq('hidden')
    expect(period).to be_nil
  end

  # The tabs pick the kind of period, the arrows turn it, and give the swipe
  # its pages
  describe 'the arrows' do
    it 'keeps them hidden on the live view, which shows no period' do
      get '/inverter_power/now'

      expect(pager['class']).to eq('hidden')
      expect(period).to be_nil
      expect(arrows).to eq(%w[/inverter_power/2026-10-22 /forecast])
    end

    it 'turns today to yesterday and to the forecast' do
      get '/inverter_power/day'

      expect(arrows).to eq(%w[/inverter_power/2026-10-22 /forecast])
    end

    it 'turns a day to the days around it' do
      get '/inverter_power/2026-10-21'

      expect(arrows).to eq(%w[/inverter_power/2026-10-20 /inverter_power/2026-10-22])
    end

    it 'has none for a period that does not turn' do
      get '/inverter_power/P365D'

      expect(arrows).to be_empty
    end
  end

  describe 'on a list' do
    before do
      login_as_admin
      allow(ChargingSession::OffsiteDetection).to receive(:enabled?).and_return(false)
    end

    it 'names the whole time of a list' do
      get '/cars/charging_sessions/wallbox/all'

      expect(period.text.squish).to eq('All time')
      expect(arrows).to be_empty
    end

    it 'turns the period of the list' do
      get '/cars/charging_sessions/wallbox/2026-09'

      expect(period.text.squish).to eq('September 2026')
      expect(arrows).to eq(%w[/cars/charging_sessions/wallbox/2026-08 /cars/charging_sessions/wallbox/2026-10])
    end

    it 'turns today to yesterday alone' do
      get '/cars/charging_sessions/wallbox/day'

      expect(arrows).to eq(%w[/cars/charging_sessions/wallbox/2026-10-22])
    end
  end

  # The forecast is the period after today. Its tabs, the arrow back to today
  # and its timeframe select belong to the page that led here.
  describe 'on the forecast' do
    before do
      allow(Sensor::Query::ForecastAvailability).to receive(:new).and_return(instance_double(Sensor::Query::ForecastAvailability, call: Date.current + 6.days))
    end

    def tabs = response.parsed_body.css('nav[aria-label="Tabs"] a').map { URI(it['href']).path }

    it 'names the days of the forecast' do
      get '/forecast'

      expect(period.text.squish).to eq('The next 7 days')
      expect(URI(period['href']).path).to eq('/forecast')
    end

    it 'leads back to the page that led here' do
      get '/power_balance/2026-10-20'
      get '/forecast'

      expect(tabs.first(2)).to eq(%w[/power_balance/now /power_balance/day])
      expect(arrows).to eq(%w[/power_balance/day])
    end

    it 'leads to the power balance of the inverter without a page before' do
      get '/forecast'

      expect(tabs.first(2)).to eq(%w[/inverter_power/now /inverter_power/day])
      expect(arrows).to eq(%w[/inverter_power/day])
    end

    # The timeframe select of the forecast marks the forecast alone, not the
    # period chosen last
    it 'marks the forecast in the timeframe select' do
      get '/inverter_power/2020'
      get '/forecast?select=1', headers: { 'Turbo-Frame' => 'modal' }

      select = response.parsed_body.at_css('.timeframe-select')
      expect(select.css('a[aria-current]').map { [it.text, it['href']] }).to eq([['Next days', '/forecast']])
      expect(select.at_css('[data-controller="timeframe--select--year-picker--component"]')['data-timeframe--select--year-picker--component-value-value']).to be_nil
      expect(select.css('a[href*="/all/by_"]').map(&:text)).to eq(%w[Months Quarters Seasons])
    end

    it 'selects a timeframe of the page that led here' do
      get '/power_balance/2026-10-20'
      get '/forecast?select=1', headers: { 'Turbo-Frame' => 'modal' }

      expect(response.parsed_body.at_css('[data-timeframe--select--component-url-template-value]')['data-timeframe--select--component-url-template-value'])
        .to eq('/power_balance/:timeframe')
    end
  end

  describe 'the links in the timeframe select' do
    def comparisons
      response.parsed_body.css('.timeframe-select a[href*="/all/by_"]')
    end

    it 'offers the comparisons of the years' do
      get '/inverter_power/2026-10?select=1', headers: { 'Turbo-Frame' => 'modal' }

      expect(comparisons.map(&:text)).to eq(%w[Months Quarters Seasons])
      expect(comparisons.none? { it['aria-current'] }).to be(true)
    end

    it 'marks the comparison of the page' do
      get '/inverter_power/all/by_season?select=1', headers: { 'Turbo-Frame' => 'modal' }

      expect(comparisons.find { it['aria-current'] }.text).to eq('Seasons')
    end

    it 'offers none on a list' do
      get '/cars/charging_sessions/2026?select=1', headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include('Select timeframe')
      expect(comparisons).to be_empty
      expect(response.parsed_body.css('.timeframe-select a[href="/forecast"]')).to be_empty
    end

    it 'offers the forecast' do
      get '/inverter_power/2026-10?select=1', headers: { 'Turbo-Frame' => 'modal' }

      forecast = response.parsed_body.at_css('.timeframe-select a[href="/forecast"]')
      expect(forecast.text).to eq('Next days')
      expect(forecast['aria-current']).to be_nil
    end
  end
end
