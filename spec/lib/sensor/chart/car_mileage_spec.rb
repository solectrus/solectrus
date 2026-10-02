describe Sensor::Chart::CarMileage do
  subject(:chart) { described_class.new(timeframe: Timeframe.new('2026'), cars: [Car.new(id: 1)]) }

  let(:today) { Date.new(2026, 9, 23) }

  before do
    travel_to today.in_time_zone.change(hour: 12)
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_MILEAGE_1' => 'Trabant:odometer',
        'INFLUX_SENSOR_CAR_MILEAGE_2' => 'Wartburg:odometer',
      ),
    )
    allow(Sensor::Config).to receive(:exists?).and_call_original
    allow(Sensor::Config).to receive(:exists?).with(:wallbox_power_grid).and_return(true)

    # 150 km in January on 30 kWh at home (10 kWh from the grid)
    summary(Date.new(2026, 1, 25), :wallbox_power, :sum, 30_000)
    summary(Date.new(2026, 1, 25), :wallbox_power_grid, :sum, 10_000)
    summary(Date.new(2026, 1, 25), :car_mileage_1, :sum, 150)

    # 50 km in March
    summary(Date.new(2026, 3, 20), :car_mileage_1, :sum, 50)

    # 30 km of the second car in March
    summary(Date.new(2026, 3, 21), :car_mileage_2, :sum, 30)
  end

  after { Sensor::Config.setup(ENV) }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  # The energy sources split the charged energy, but not the distance: the
  # charge of a day says nothing about the energy of a drive.
  it 'has one dataset with the distance of each column, even with the power splitter' do
    dataset = chart.data[:datasets].sole

    expect(dataset[:id]).to eq('car_mileage_1')
    expect(dataset[:data].first(3)).to eq([150, nil, 50])
  end

  it 'does not stack the columns' do
    expect(chart.options.dig(:scales, :y, :stacked)).to be_falsy
  end

  context 'with all cars' do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026')) }

    before { Car.create!(id: 2, name: 'Wartburg', color: '#ff0000') }

    it 'shows each car in a column of its own, with its name, in the color of the sensor' do
      datasets = chart.data[:datasets]

      expect(datasets.pluck(:label)).to eq(['Car 1', 'Wartburg'])
      expect(datasets.pluck(:colorClass).uniq).to eq(['bg-sensor-wallbox'])
      expect(datasets.map { it[:data][2] }).to eq([50, 30])
      expect(datasets.pluck(:stack).uniq).to eq(['Car-Mileage'])
    end
  end
end
