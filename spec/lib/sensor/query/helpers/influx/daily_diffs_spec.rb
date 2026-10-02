describe Sensor::Query::Helpers::Influx::DailyDiffs do
  subject(:call) { described_class.new(dates, [:car_mileage_1]).call }

  before do
    stub_const('ENV', ENV.to_h.merge('INFLUX_SENSOR_CAR_MILEAGE_1' => 'Trabant:mileage'))
    stub_feature(:car)

    measurement = Sensor::Config.measurement(:car_mileage_1)
    field = Sensor::Config.field(:car_mileage_1)

    influx_batch do
      readings.each do |time, value|
        add_influx_point(name: measurement, fields: { field => value.to_f }, time:)
      end
    end
  end

  # Sparse readings: a day without a reading, a day with several, and
  # readings before and after the dates
  let(:readings) do
    [
      [Time.zone.local(2024, 3, 7, 18), 1000],
      [Time.zone.local(2024, 3, 9, 7), 1040],
      [Time.zone.local(2024, 3, 9, 12), 1090],
      [Time.zone.local(2024, 3, 9, 19), 1100],
      [Time.zone.local(2024, 3, 12, 6), 1280],
    ]
  end

  # With a gap: March 10 is not asked for, but its boundary counts
  let(:dates) { [Date.new(2024, 3, 8), Date.new(2024, 3, 9), Date.new(2024, 3, 11)] }

  it 'returns the same diff as each day on its own' do
    dates.each do |date|
      single = Sensor::Query::InterpolatedDiff.call(sensor_name: :car_mileage_1, timeframe: Timeframe.new(date.iso8601))

      expect(call[date][:car_mileage_1]).to be_within(0.001).of(single), "differs for #{date}"
    end
  end

  it 'needs one query for all days' do
    allow(Influx).to receive(:query).and_call_original

    call

    expect(Influx).to have_received(:query).once
  end

  context 'with dates far apart' do
    let(:dates) { [Date.new(2024, 3, 8), Date.new(2024, 3, 11), Date.new(2024, 9, 1)] }

    it 'returns the same diff as each day on its own' do
      dates.each do |date|
        single = Sensor::Query::InterpolatedDiff.call(sensor_name: :car_mileage_1, timeframe: Timeframe.new(date.iso8601))

        expect(call[date][:car_mileage_1]).to be_within(0.001).of(single), "differs for #{date}"
      end
    end

    it 'reads the days asked for, not the span between them' do
      allow(Influx).to receive(:query).and_call_original

      call

      expect(Influx).to have_received(:query).with(satisfy { it.scan('|> first()').size == 6 })
    end
  end

  context 'without a reading' do
    let(:readings) { [] }

    it 'returns nil' do
      expect(call.values.pluck(:car_mileage_1)).to all(be_nil)
    end
  end

  context 'without a configured sensor' do
    subject(:call) { described_class.new(dates, [:car_mileage_2]).call }

    it 'queries nothing' do
      allow(Influx).to receive(:query)

      expect(call).to eq({})
      expect(Influx).not_to have_received(:query)
    end
  end
end
