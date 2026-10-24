# The timeframe of a phone: the live view and today, and the period, in one row
# (see TimeframeSegments)
describe 'Timeframe segments' do
  before { travel_to Time.zone.local(2026, 10, 23, 12) }

  def segments
    response.parsed_body.css('nav[aria-label="Timeframe"] > a')
  end

  # The period lies between the live view and today. A list has no link for
  # the live view.
  def period_segment = segments[-2]

  it 'names the current year while no period was chosen' do
    get '/inverter_power/now'

    expect(segments.map { it.text.squish }).to eq(%w[Now 2026 Today])
    expect(segments.first['aria-current']).to eq('page')
    expect(segments.last['href']).to end_with('/inverter_power/day')
  end

  # A segment that is not the current one leads to its period at once, and a
  # long press on it opens the sheet
  it 'leads from the live view to the current period of the kind chosen last' do
    get '/inverter_power/2026-09'
    get '/inverter_power/now'

    expect(period_segment.text.squish).to eq('October 2026')
    expect(period_segment['href']).to end_with('/inverter_power/month')
    expect(period_segment['data-turbo-frame']).to be_nil
    expect(period_segment['data-controller']).to eq('timeframe--segments--component')
  end

  # The chevron promises the sheet, so it shows only where a tap opens it. It
  # keeps its room elsewhere, so the name does not move.
  it 'shows the chevron on the current period alone' do
    get '/inverter_power/day'
    expect(period_segment.at_css('svg')['class']).to include('invisible')

    get '/inverter_power/2026'
    expect(period_segment.at_css('svg')['class']).not_to include('invisible')
  end

  it 'names the current week or year of the kind chosen last' do
    get '/inverter_power/2026-W37'
    get '/inverter_power/day'
    expect(period_segment.text.squish).to eq(Timeframe.week.localized)

    get '/inverter_power/2024'
    get '/inverter_power/day'
    expect(period_segment.text.squish).to eq('2026')
  end

  it 'names the current month after a day or a range' do
    get '/inverter_power/2026-10-21'
    get '/inverter_power/day'
    expect(period_segment.text.squish).to eq('October 2026')

    get '/inverter_power/2025-09-01..2025-10-15'
    get '/inverter_power/day'
    expect(period_segment.text.squish).to eq('October 2026')
  end

  # A window counted back from now does not turn, so it is no kind of period
  it 'keeps the period before a window counted back from now' do
    get '/inverter_power/2026-W37'
    get '/inverter_power/P90D'
    get '/inverter_power/day'

    expect(segments.last['aria-current']).to eq('page')
    expect(period_segment.text.squish).to eq(Timeframe.week.localized)
  end

  it 'keeps the whole time' do
    get '/inverter_power/all'
    get '/inverter_power/day'

    expect(period_segment.text.squish).to eq('Overall')
  end

  # The current period opens the timeframe select in the sheet, with a tap and
  # with a long press
  it 'opens the sheet from the current period' do
    get '/inverter_power/2026-10'

    expect(period_segment['aria-current']).to eq('page')
    expect(period_segment['data-turbo-frame']).to eq('modal')
    expect(period_segment['href']).to end_with('/inverter_power/2026-10?select=1')
    expect(period_segment['data-controller']).to include('timeframe--segments--component')
  end

  # A long press opens the timeframe select also from another segment
  it 'leads to the period, and opens its select with a long press' do
    get '/inverter_power/day'

    expect(period_segment['data-turbo-frame']).to be_nil
    expect(period_segment['href']).not_to include('select')
    expect(period_segment['data-timeframe--segments--component-href-value']).to end_with('select=1')
  end

  it 'names a day of this year without its year' do
    get '/inverter_power/2026-10-21'

    expect(period_segment.text.squish).to eq('Wed, Oct 21')
  end

  it 'names a range within one year with its year once' do
    get '/inverter_power/2025-09-01..2025-10-15'

    expect(period_segment.text.squish).to eq('Sep 01 – Oct 15 2025')
  end

  it 'names the comparison of the years' do
    get '/inverter_power/all/by_month'

    expect(period_segment.text.squish).to eq('Year comparison')
    expect(period_segment['href']).to end_with('/inverter_power/all/by_month?select=1')
  end

  # The arrows turn the page, and give the swipe its pages
  describe 'the arrows' do
    def arrows
      links = response.parsed_body.css('nav[aria-label="Timeframe"] a[data-nav]')
      links.map { URI(it['href']).path }
    end

    it 'turns the live view as today' do
      get '/inverter_power/2026-09'
      get '/inverter_power/now'

      expect(arrows).to eq(%w[/inverter_power/2026-10-22 /forecast])
    end

    it 'turns today to yesterday and to the forecast' do
      get '/inverter_power/2026-09'
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

  # A list has the same row, without a live view
  describe 'on a list' do
    before do
      login_as_admin
      allow(ChargingSession::OffsiteDetection).to receive(:enabled?).and_return(false)
    end

    def live = response.parsed_body.at_css('nav[aria-label="Timeframe"] > span[aria-disabled]')

    it 'disables the live view and names the whole time' do
      get '/cars/charging_sessions/wallbox/all'

      expect(live.text).to eq('Now')
      expect(segments.map { it.text.squish }).to eq(%w[Overall Today])
      expect(period_segment['aria-current']).to eq('page')
    end

    it 'turns the period of the list' do
      get '/cars/charging_sessions/wallbox/2026-09'

      expect(period_segment.text.squish).to eq('September 2026')
      expect(response.parsed_body.css('nav[aria-label="Timeframe"] a[aria-label]').map { URI(it['href']).path })
        .to eq(%w[/cars/charging_sessions/wallbox/2026-08 /cars/charging_sessions/wallbox/2026-10])
    end

    it 'keeps the whole time beside today' do
      get '/cars/charging_sessions/wallbox/day'

      expect(segments.last['aria-current']).to eq('page')
      expect(period_segment['href']).to end_with('/cars/charging_sessions/wallbox/all')
      expect(response.parsed_body.at_css('nav[aria-label="Timeframe"] a[data-nav="prev"]')['href'])
        .to end_with('/cars/charging_sessions/wallbox/2026-10-22')
    end
  end

  # The forecast is the period after today. Its live view, today and its
  # timeframe select belong to the page that led here.
  describe 'on the forecast' do
    before do
      allow(Sensor::Query::ForecastAvailability).to receive(:new).and_return(instance_double(Sensor::Query::ForecastAvailability, call: Date.current + 6.days))
    end

    it 'names the days of the forecast' do
      get '/forecast'

      expect(segments.map { it.text.squish }).to eq(['Now', 'Next 7 days', 'Today'])
      expect(period_segment['aria-current']).to eq('page')
      expect(period_segment['data-turbo-frame']).to eq('modal')
      expect(URI(period_segment['href']).path).to eq('/forecast')
    end

    it 'leads back to the page that led here' do
      get '/power_balance/2026-10-20'
      get '/forecast'

      expect(segments.map { URI(it['href']).path }).to eq(%w[/power_balance/now /forecast /power_balance/day])
      expect(response.parsed_body.at_css('nav[aria-label="Timeframe"] a[data-nav="prev"]')['href']).to eq('/power_balance/day')
    end

    it 'leads to the power balance of the inverter without a page before' do
      get '/forecast'

      expect(segments.map { URI(it['href']).path }).to eq(%w[/inverter_power/now /forecast /inverter_power/day])
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
