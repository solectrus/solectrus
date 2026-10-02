describe Sensor::Chart::CarMaxRange do
  subject(:chart) { described_class.new(timeframe: Timeframe.new('2026'), car_number: 1) }

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
end
