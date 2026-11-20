# The insights of a chart of the car page are a page of the sheet of its
# trends (see InsightsController#trend_overview?)
describe 'Car Insights' do
  let(:headers) { { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/cars/1/2026-01' } }

  def summary(date, field, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation: 'sum', value:)
  end

  before do
    travel_to Time.zone.local(2026, 9, 23, 12)

    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_ODOMETER' => 'Trabant:odometer',
        'INFLUX_SENSOR_CAR_ODOMETER_2' => 'Wartburg:odometer',
      ),
    )
    Current.cars = nil
  end

  after { Sensor::Config.setup(ENV) }

  # A visitor sees the data up to the day before yesterday (see
  # Car::AdminOnlyDays)
  it 'ends the data of a visitor with the latest public day' do
    allow(Insights::CarComparison).to receive(:new).and_call_original
    get(insights_path(sensor_name: 'car_distance', timeframe: '2026-09', car: 1), headers:)

    expect(Insights::CarComparison).to have_received(:new).with(hash_including(timeframe: having_attributes(effective_ending_date: Date.new(2026, 9, 21))))
  end

  # The charts of the trends of the car page. The maximum range needs a sensor
  # of its own, which this setup has not.
  %w[
    car_distance
    car_charging
    car_charging_costs
    car_driving_energy
    car_driving_costs
    car_cost_rate
    car_consumption_rate
  ].each do |sensor_name|
    it "renders #{sensor_name}" do
      get(insights_path(sensor_name:, timeframe: '2026-01', car: 1), headers:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('tooltip-layout insights')
    end
  end

  # Outside the sheet of the trends, a chart of the car page has no details
  it 'shows the head alone outside the trends' do
    get(insights_path(sensor_name: 'car_distance', timeframe: '2026-01', car: 1), headers: { 'Turbo-Frame' => 'modal' })

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('insights-row')
  end

  context 'with a car that replaced another one' do
    before do
      first, second = Car.configured
      first.update!(active_until: Date.new(2025, 12, 31))
      second.update!(active_from: Date.new(2026, 1, 1))

      summary(Date.new(2025, 1, 1), 'car_odometer_1', 0)
      summary(Date.new(2025, 1, 10), 'car_odometer_1', 100)
      summary(Date.new(2026, 1, 1), 'car_odometer_2', 0)
      summary(Date.new(2026, 1, 10), 'car_odometer_2', 150)
      summary(Date.new(2026, 1, 20), 'car_odometer_2', 50)
    end

    it 'compares "all" with the cars of the previous year' do
      get(insights_path(sensor_name: 'car_distance', timeframe: '2026-01'), headers:)

      expect(response.body).to match(/Jan 2026.*200 km.*Jan 2025.*100 km/m)
    end

    it 'shows the day with the highest distance of the new car alone' do
      get(insights_path(sensor_name: 'car_distance', timeframe: '2026-01', car: 2), headers:)

      expect(Capybara.string(response.body)).to have_css('.insights-row', text: /Maximum.*150 km/)
    end

    # The button beside the timeframe opens the trends of a month
    it 'links the timeframe to the trends of the selected car' do
      get(cars_charts_path(car: 2, sensor_name: 'car_distance', timeframe: '2026-01'), headers: { 'Turbo-Frame' => 'modal' })

      expect(response.body).to include('href="/trends/2026-01?car=2"')
    end
  end
end
