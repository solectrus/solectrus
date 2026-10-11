describe 'Top 10 of the cars' do
  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer',
        'INFLUX_SENSOR_CAR_ODOMETER_2' => 'Wartburg:odometer',
        'INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range',
        'INFLUX_SENSOR_CAR_RANGE_2' => 'Wartburg:range',
        'INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc',
      ),
    )
    Current.cars = nil
  end

  after { Sensor::Config.setup(ENV) }

  let(:html) { response.parsed_body }

  def options(name) = html.css("select[name=#{name}] option").to_h { [it.text.squish, it['value']] }

  it 'offers each role once, for the car of the current sensor' do
    get '/top10/day/car_odometer_2/sum/desc'

    sensors = options('sensor-selector')
    expect(sensors['Distance driven']).to eq('/top10/day/car_odometer_2/sum/desc')
    expect(sensors['Maximum range']).to eq('/top10/day/car_max_range_2/sum/desc')
    expect(sensors.keys.join).not_to include('Odometer', 'Car 2')
  end

  it 'offers the distance of all cars for another sensor' do
    get '/top10/day/inverter_power/sum/desc'

    expect(options('sensor-selector')['Distance driven']).to eq('/top10/day/car_distance/sum/desc')
    expect(options('car')).to be_empty
  end

  it 'offers the cars and all cars in a select of their own' do
    get '/top10/day/car_odometer_2/sum/desc'

    expect(options('car')).to eq(
      'All cars' => '/top10/day/car_distance/sum/desc',
      'Car 1' => '/top10/day/car_odometer_1/sum/desc',
      'Car 2' => '/top10/day/car_odometer_2/sum/desc',
    )
  end

  it 'offers no choice of all cars for the maximum range' do
    get '/top10/day/car_max_range_2/avg/desc'

    expect(options('car').keys).to eq(['Car 1', 'Car 2'])
  end

  describe 'the chart of all cars' do
    before do
      Summary.create!(date: Date.new(2026, 1, 1))
      Summary.create!(date: Date.new(2026, 1, 2))
      SummaryValue.create!(date: Date.new(2026, 1, 1), field: :car_odometer_1, aggregation: :sum, value: 30)
      SummaryValue.create!(date: Date.new(2026, 1, 1), field: :car_odometer_2, aggregation: :sum, value: 50)
      SummaryValue.create!(date: Date.new(2026, 1, 2), field: :car_odometer_2, aggregation: :sum, value: 60)
    end

    it 'ranks the distance of all cars together' do
      ranking = Sensor::Query::Ranking.new(:car_distance, aggregation: :sum, period: :day).call

      expect(ranking.first(2)).to eq([{ date: Date.new(2026, 1, 1), value: 80.0 }, { date: Date.new(2026, 1, 2), value: 60.0 }])
    end
  end
end
