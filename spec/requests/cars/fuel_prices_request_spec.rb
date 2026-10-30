describe 'Cars Fuel Prices' do
  let(:car) { Car.configured.first }
  let(:fuel_prices) { Car::FuelPrices.new('petrol') }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  before do
    travel_to Date.new(2026, 9, 23).in_time_zone.change(hour: 12)
    allow(Car::Report).to receive(:pending_days).and_return([])
    allow(Car::FuelPrices).to receive(:new).and_return(fuel_prices)
    allow(fuel_prices).to receive(:points).and_return([[Date.new(2026, 1, 5), 2.0], [Date.new(2026, 2, 2), 1.5]])

    # The odometer reads since December, so each window starts before the
    # charges
    summary(Date.new(2025, 12, 1), :car_odometer_1, :sum, 0)

    # 30 kWh for 4.60 EUR, 150 km in January and 100 km in February
    start = Date.new(2026, 1, 20).in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: start, ended_at: start + 1.hour, kwh: 30, kwh_grid: 10, cost: 4.6, cost_grid: 3.0)
    summary(Date.new(2026, 1, 25), :car_odometer_1, :sum, 150)
    summary(Date.new(2026, 2, 3), :car_odometer_1, :sum, 100)
  end

  # The figures above the chart, each with its texts
  def figures = response.parsed_body.css('.grid > div').map { it.xpath('.//text()').map { it.text.strip }.compact_blank.join(' ') }.compact_blank

  def chart_data = JSON.parse(response.parsed_body.at_css('script[type="application/json"]').text)

  # The prices are public data, like the page of the comparison
  it 'shows the modal to a visitor too' do
    car.update!(active_from: Date.new(2025, 1, 1), fuel_type: 'petrol', fuel_consumption: 8)

    get cars_fuel_prices_path

    expect(response).to have_http_status(:ok)
  end

  context 'with the admin' do
    before { login_as_admin }

    it 'has nothing without a combustion car' do
      get cars_fuel_prices_path

      expect(response).to have_http_status(:not_found)
    end

    context 'with a combustion car' do
      before { car.update!(active_from: Date.new(2025, 1, 1), fuel_type: 'petrol', fuel_consumption: 8) }

      # 2026 has 2 EUR/l from January 5 and 1.50 EUR/l from February 2 up to
      # today
      it 'shows the prices of the timeframe without an average' do
        get cars_fuel_prices_path(timeframe: '2026')

        expect(response.parsed_body.css('h1').map { it.text.squish }).to include('Petrol prices')
        expect(figures).to eq(['Lowest € 1.50/l Feb 2026', 'Highest € 2.00/l Jan 2026'])
        expect(chart_data).to eq(
          'lines' => [{ 'label' => 'Petrol', 'points' => [{ 'x' => '2026-01-05', 'y' => 2.0 }, { 'x' => '2026-02-02', 'y' => 1.5 }, { 'x' => '2026-09-23', 'y' => 1.5 }] }],
        )
      end

      # The reversed range matches the route, but is no timeframe
      it 'shows the whole time for an invalid timeframe' do
        get '/cars/savings/fuel_prices/2026-05-01..2026-04-01'

        expect(response).to have_http_status(:ok)
      end

      it 'opens from the price range of the page' do
        get cars_savings_path(timeframe: '2026'), headers: { 'Turbo-Frame' => 'comparison' }

        link = response.parsed_body.at_css('turbo-frame a[href="/cars/savings/fuel_prices/2026"]')

        expect(link.text.squish).to eq('1.50 – 2.00')
        expect(link['data-turbo-frame']).to eq('modal')
      end
    end
  end
end
