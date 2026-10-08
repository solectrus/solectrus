describe 'Car Insights' do
  let(:headers) { { 'Turbo-Frame' => 'modal' } }

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

  %w[
    car_distance
    car_charging
    car_charging_costs
    car_driving_costs
    car_cost_rate
    car_consumption_rate
    car_max_range
  ].each do |sensor_name|
    it "renders #{sensor_name}" do
      get(insights_path(sensor_name:, timeframe: '2026-01', car: 1), headers:)

      expect(response).to have_http_status(:ok)
    end
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

      expect(response.body).to include('Previous year', '+100', 'href="/cars/car_distance/2025-01"')
      # The previous month has no distance
      expect(response.body).not_to include('Previous month')
    end

    it 'shows the day with the highest distance' do
      get(insights_path(sensor_name: 'car_distance', timeframe: '2026-01', car: 2), headers:)

      expect(response.body).to include('Maximum', 'href="/cars/2/car_distance/2026-01-10"')
    end

    it 'has no trend for the new car alone' do
      get(insights_path(sensor_name: 'car_distance', timeframe: '2026-01', car: 2), headers:)

      expect(response.body).not_to include('Previous year')
    end

    it 'links the chart to the insights of the selected car' do
      get(cars_charts_path(car: 2, sensor_name: 'car_distance', timeframe: '2026-01'), headers:)

      expect(response.body).to include('href="/insights/car_distance/2026-01?car=2"')
    end
  end
end
