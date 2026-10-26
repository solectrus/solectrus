describe Sensor::Chart::CarDistance do
  subject(:chart) { described_class.new(timeframe: Timeframe.new('2026'), cars: [Car.new(id: 1)]) }

  let(:today) { Date.new(2026, 9, 23) }

  before do
    travel_to today.in_time_zone.change(hour: 12)
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer',
        'INFLUX_SENSOR_CAR_ODOMETER_2' => 'Wartburg:odometer',
      ),
    )
    allow(Sensor::Config).to receive(:exists?).and_call_original
    allow(Sensor::Config).to receive(:exists?).with(:wallbox_power_grid).and_return(true)

    # 150 km in January on 30 kWh at home (10 kWh from the grid)
    summary(Date.new(2026, 1, 25), :wallbox_power, :sum, 30_000)
    summary(Date.new(2026, 1, 25), :wallbox_power_grid, :sum, 10_000)
    summary(Date.new(2026, 1, 25), :car_odometer_1, :sum, 150)

    # 50 km in March
    summary(Date.new(2026, 3, 20), :car_odometer_1, :sum, 50)

    # 30 km of the second car in March
    summary(Date.new(2026, 3, 21), :car_odometer_2, :sum, 30)
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

    expect(dataset[:id]).to eq('car_odometer_1')
    expect(dataset[:data].first(3)).to eq([150, nil, 50])
  end

  describe '.supports?' do
    it 'draws a week and longer' do
      expect(
        [Timeframe.new('2026-W26'), Timeframe.new('2026')].map do
          described_class.supports?(it)
        end,
      ).to all(be(true))
    end

    # A day has the timeline of the day instead
    it 'does not draw the live view, hours or a day' do
      expect([Timeframe.now, Timeframe.new('P1H'), Timeframe.new('2026-06-26')].map { described_class.supports?(it) }).to all(be(false))
    end
  end

  context 'with a month without a drive' do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026-02'), cars: [Car.new(id: 1)]) }

    # A parked car has a distance of 0
    before { summary(Date.new(2026, 2, 10), :car_odometer_1, :sum, 0) }

    it 'is blank and shows a road instead of a message' do
      expect(chart).to be_blank
      expect(chart.blank_message).to eq(I18n.t('data.car_no_driving'))
      expect(chart.blank_icon).to eq('road')
    end

    # A drive can still come in the running month
    it 'shows "yet" in the running month' do
      travel_to Date.new(2026, 2, 20)

      expect(chart.blank_message).to eq(I18n.t('data.car_no_driving_yet'))
    end
  end

  it 'does not stack the columns' do
    expect(chart.options.dig(:scales, :y, :stacked)).to be_falsy
  end

  context 'with all cars' do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026'), cars: Car.configured) }

    before { Car.create!(id: 2, name: 'Wartburg', color: '#ff0000') }

    it 'stacks a part for each car, with its name, tinted with its color' do
      datasets = chart.data[:datasets]

      expect(datasets.pluck(:label)).to eq(['Car 1', 'Wartburg'])
      expect(datasets.pluck(:tintColor)).to eq([Car::DEFAULT_COLOR, '#ff0000'])
      expect(datasets.map { it[:data][2] }).to eq([50, 30])
      expect(datasets.pluck(:stack).uniq).to eq(['CarDistance'])
      expect(datasets.pluck(:summed)).to all(be(true))
    end
  end
end
