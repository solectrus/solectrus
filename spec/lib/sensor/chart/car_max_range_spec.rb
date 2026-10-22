describe Sensor::Chart::CarMaxRange do
  subject(:chart) { described_class.new(timeframe: Timeframe.new('2026'), cars: [Car.new(id: 1, active_from: Date.new(2020, 1, 1))]) }

  before do
    travel_to Time.zone.local(2026, 9, 23, 12)
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range',
        'INFLUX_SENSOR_CAR_BATTERY_SOC_1' => 'Trabant:soc',
      ),
    )

    summary(Date.new(2026, 1, 15), 250)
    summary(Date.new(2026, 2, 15), 260)
  end

  def summary(date, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field: :car_max_range_1, aggregation: :avg, value:)
  end

  it 'starts the year with January' do
    expect(Time.zone.at(chart.data[:labels].first / 1000).to_date).to eq(Date.new(2026, 1, 1))
    expect(chart.data[:datasets].first[:data].first(2)).to eq([250, 260])
  end

  # The maximum range has no reading of its own, so the day starts with the
  # one from the last range and charge before it
  context 'with a day that starts without a reading' do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026-09-22'), cars: [Car.new(id: 1, active_from: Date.new(2020, 1, 1))]) }

    def add_reading(range, soc, time)
      influx_batch do
        add_influx_point(name: 'Trabant', fields: { range:, soc: }, time:)
      end
    end

    before do
      add_reading(160.0, 50.0, Time.zone.local(2026, 9, 21, 18))
      add_reading(165.0, 50.0, Time.zone.local(2026, 9, 22, 8))
    end

    it 'holds the maximum range from midnight' do
      values = chart.data[:datasets].first[:data]

      expect(values.first).to eq(320.0)
      expect(values.compact.uniq).to eq([320.0, 330.0])
    end
  end
end
