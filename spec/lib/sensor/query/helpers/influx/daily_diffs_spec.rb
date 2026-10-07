describe Sensor::Query::Helpers::Influx::DailyDiffs do
  subject(:call) { described_class.new(dates, [:car_odometer_1]).call }

  before do
    stub_const('ENV', ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:mileage'))
    stub_feature(:car)

    measurement = Sensor::Config.measurement(:car_odometer_1)
    field = Sensor::Config.field(:car_odometer_1)

    influx_batch do
      readings.each do |time, value|
        add_influx_point(name: measurement, fields: { field => value.to_f }, time:)
      end
    end
  end

  def diffs = call.transform_values { it[:car_odometer_1] }

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

  # 40 km in the 37 hours from March 7, 18:00, to March 9, 07:00, and 180 km
  # in the 59 hours from March 9, 19:00, to March 12, 06:00
  it 'interpolates the reading at each midnight' do
    expect(diffs[Date.new(2024, 3, 8)]).to be_within(0.001).of(40 * 24 / 37.0)
    expect(diffs[Date.new(2024, 3, 9)]).to be_within(0.001).of(((180 * 5 / 59.0) + 1100) - ((40 * 30 / 37.0) + 1000))
    expect(diffs[Date.new(2024, 3, 11)]).to be_within(0.001).of(180 * 24 / 59.0)
  end

  it 'needs one query for all days' do
    allow(Influx).to receive(:query).and_call_original

    call

    expect(Influx).to have_received(:query).once
  end

  # A collector that writes 0 while the car is offline. The 0 is the last
  # reading of March 9 and the first of March 12, so it is at a boundary.
  context 'with a 0 of an offline car' do
    let(:readings) { super() + [[Time.zone.local(2024, 3, 9, 23), 0], [Time.zone.local(2024, 3, 12, 0, 30), 0]] }

    it 'leaves it out' do
      expect(diffs[Date.new(2024, 3, 9)]).to be_within(0.001).of(((180 * 5 / 59.0) + 1100) - ((40 * 30 / 37.0) + 1000))
      expect(diffs[Date.new(2024, 3, 11)]).to be_within(0.001).of(180 * 24 / 59.0)
    end

    # The 0 hides the readings beside it, which only a filter on the value finds
    it 'reads the readings above 0 in a second query' do
      allow(Influx).to receive(:query).and_call_original

      call

      expect(Influx).to have_received(:query).twice
    end
  end

  context 'with consecutive days' do
      let(:dates) { (Date.new(2024, 3, 7)..Date.new(2024, 3, 12)).to_a }

      # The first reading stands in before it, and the last one after it
      it 'adds up to the increase over the whole range' do
        expect(diffs.values.sum).to be_within(0.001).of(280)
      end
  end

  context 'with dates far apart' do
    let(:dates) { [Date.new(2024, 3, 8), Date.new(2024, 3, 11), Date.new(2024, 9, 1)] }

    it 'reads the days asked for, not the span between them' do
      allow(Influx).to receive(:query).and_call_original

      call

      expect(Influx).to have_received(:query).with(satisfy { it.scan('|> first()').size == 6 })
    end

    it 'gives the same diffs as the consecutive days' do
      expect(diffs[Date.new(2024, 3, 11)]).to be_within(0.001).of(180 * 24 / 59.0)
    end

    it 'gives no increase after the last reading' do
      expect(diffs[Date.new(2024, 9, 1)]).to eq(0)
    end
  end

  context 'with a reading exactly at midnight' do
    let(:readings) do
      [
        [Time.zone.local(2024, 3, 9, 12), 900],
        [Time.zone.local(2024, 3, 10), 1234],
        [Time.zone.local(2024, 3, 10, 12), 1300],
        [Time.zone.local(2024, 3, 11, 12), 1400],
      ]
    end
    let(:dates) { [Date.new(2024, 3, 10)] }

    it 'takes this reading without interpolating' do
      expect(diffs[Date.new(2024, 3, 10)]).to be_within(0.001).of(1350 - 1234)
    end
  end

  context 'with the running day' do
    let(:readings) { [[Time.zone.local(2024, 3, 10, 8), 1000], [Time.zone.local(2024, 3, 10, 10), 1040]] }
    let(:dates) { [Date.new(2024, 3, 10)] }

    before { travel_to Time.zone.local(2024, 3, 10, 12) }

    it 'ends now instead of extrapolating' do
      expect(diffs[Date.new(2024, 3, 10)]).to eq(40)
    end
  end

  # The odometer came after the installation, so the days before its first
  # reading have no value and not a distance of 0
  context 'with days before the first reading' do
    let(:dates) { [Date.new(2024, 3, 5), Date.new(2024, 3, 6), Date.new(2024, 3, 7)] }

    it 'gives them no value and the day of the first reading its increase' do
      expect(diffs.values_at(Date.new(2024, 3, 5), Date.new(2024, 3, 6))).to eq([nil, nil])
      expect(diffs[Date.new(2024, 3, 7)]).to be_within(0.001).of(40 * 6 / 37.0)
    end
  end

  context 'with the installation day' do
    let(:dates) { [Rails.configuration.x.installation_date] }
    let(:readings) { [[dates.first.in_time_zone.change(hour: 8), 1000], [dates.first.in_time_zone.change(hour: 20), 1100]] }

    it 'gives no diff, because nothing was read before' do
      expect(diffs[dates.first]).to be_nil
    end
  end

  context 'without a reading' do
    let(:readings) { [] }

    it 'returns nil' do
      expect(diffs.values).to all(be_nil)
    end
  end

  context 'without a configured sensor' do
    subject(:call) { described_class.new(dates, [:car_odometer_2]).call }

    it 'queries nothing' do
      allow(Influx).to receive(:query)

      expect(call).to eq({})
      expect(Influx).not_to have_received(:query)
    end
  end

  context 'with the cache' do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(Influx).to receive(:query).and_call_original
    end

    def call_twice = Array.new(2) { described_class.new(dates, [:car_odometer_1], cache: true).call }

    # The reading of March 12 follows the last date, so a later reading
    # cannot change the diffs
    it 'reads final points once' do
      first, second = call_twice

      expect(second).to eq(first)
      expect(Influx).to have_received(:query).once
    end

    context 'without a reading after the last date' do
      let(:dates) { [Date.new(2024, 3, 12)] }

      it 'reads the points again, because a later reading changes the end' do
        call_twice

        expect(Influx).to have_received(:query).twice
      end
    end
  end
end
