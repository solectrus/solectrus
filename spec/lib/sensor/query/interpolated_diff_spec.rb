describe Sensor::Query::InterpolatedDiff do
  subject(:result) do
    described_class.call(sensor_name: :car_mileage_1, timeframe:)
  end

  before do
    stub_const('ENV', ENV.to_h.merge('INFLUX_SENSOR_CAR_MILEAGE_1' => 'Trabant:mileage'))
    stub_feature(:car)
  end

  let(:measurement) { Sensor::Config.measurement(:car_mileage_1) }
  let(:field) { Sensor::Config.field(:car_mileage_1) }

  def add_mileage(time:, value:)
    add_influx_point(name: measurement, fields: { field => value.to_f }, time:)
  end

  describe '.call' do
    context 'with sparse readings far apart' do
      # Jan 1 2023: 1000 km, Dec 31 2023: 10000 km -> 9000 km / 364 days.
      before do
        add_mileage(time: Time.zone.local(2023, 1, 1, 0, 0, 0), value: 1000)
        add_mileage(time: Time.zone.local(2023, 12, 31, 0, 0, 0), value: 10_000)
      end

      context 'when querying a day far inside the gap' do
        let(:timeframe) { Timeframe.new('2023-06-15') }

        it 'returns the linear daily share (~24.66 km)' do
          expect(result).to be_within(0.01).of(9000.0 / 364)
        end
      end

      it 'summing all daily diffs across the gap equals the total distance' do
        start_date = Date.new(2023, 1, 1)
        end_date = Date.new(2023, 12, 30)
        total =
          (start_date..end_date).sum do |date|
            described_class.call(
              sensor_name: :car_mileage_1,
              timeframe: Timeframe.new(date.iso8601),
            ).to_f
          end

        expect(total).to be_within(0.01).of(9000.0)
      end
    end

    context 'with dense readings on a single day and no earlier anchor' do
      # Two readings on the day, nothing before. Start anchor falls back
      # to the first known value (5000), end anchor linearly extrapolates
      # within the day toward... no later point, so falls back to last
      # known (5100). Result: the full in-day span.
      let(:timeframe) { Timeframe.new('2024-03-10') }

      before do
        add_mileage(time: Time.zone.local(2024, 3, 10, 8, 0, 0), value: 5000)
        add_mileage(time: Time.zone.local(2024, 3, 10, 20, 0, 0), value: 5100)
      end

      it 'captures the first-day distance using the first reading as start anchor' do
        expect(result).to be_within(0.01).of(100.0)
      end
    end

    context 'with a reading before and after the day' do
      # Known point on day-1 at 18:00, another on day+1 at 06:00.
      # Span = 36h, span value = 180 km => 5 km/h. Day = 24h => 120 km.
      let(:timeframe) { Timeframe.new('2024-03-10') }

      before do
        add_mileage(time: Time.zone.local(2024, 3, 9, 18, 0, 0), value: 1000)
        add_mileage(time: Time.zone.local(2024, 3, 11, 6, 0, 0), value: 1180)
      end

      it 'interpolates a plausible daily distance' do
        expect(result).to be_within(0.01).of(120.0)
      end
    end

    context 'when no readings exist at all' do
      let(:timeframe) { Timeframe.new('2024-03-10') }

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end
end
