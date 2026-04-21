describe Sensor::Query::Series do
  subject(:series_query) { described_class.new([:house_power], timeframe) }

  before do
    # Mock ApplicationPolicy to allow heatpump sensors
    stub_feature(:heatpump)
  end

  describe '#call' do
    subject(:result) { series_query.call }

    before do
      freeze_time

      # Setup test data with house_power and heatpump_power (which should be subtracted)
      influx_batch do
        add_influx_point(
          name: Sensor::Config.measurement(:house_power),
          fields: {
            Sensor::Config.field(:house_power) => 2000.0,
          },
          time: 90.minutes.ago,
        )

        add_influx_point(
          name: Sensor::Config.measurement(:heatpump_power),
          fields: {
            Sensor::Config.field(:heatpump_power) => 500.0,
          },
          time: 90.minutes.ago,
        )

        add_influx_point(
          name: Sensor::Config.measurement(:house_power),
          fields: {
            Sensor::Config.field(:house_power) => 2200.0,
          },
          time: 60.minutes.ago,
        )

        add_influx_point(
          name: Sensor::Config.measurement(:heatpump_power),
          fields: {
            Sensor::Config.field(:heatpump_power) => 600.0,
          },
          time: 60.minutes.ago,
        )
      end
    end

    context 'when timeframe is hours' do
      let(:timeframe) { Timeframe.new('P2H') }

      it 'returns time series data with proper structure' do
        expect(result).to be_a(Sensor::Data::Series)

        # Series data uses meta-aggregation access pattern: sensor(:meta_agg, :agg)
        house_power_series = result.house_power(:avg, :avg)
        expect(house_power_series).not_to be_empty

        # Check that each time point has the expected structure.
        # Values may be nil for empty aggregateWindow buckets (Flux emits
        # them by default), so charts can render real data gaps as breaks.
        house_power_series.each do |time, value|
          expect(time).to be_a(Time)

          next if value.nil?

          expect(value).to be_a(Numeric)
          expect(value).to be >= 0
          expect(value).to be <= 2200.0
        end
      end

      it 'returns series with proper time ordering' do
        house_power_series = result.house_power(:avg, :avg)
        dates = house_power_series.keys

        expect(dates).to eq(dates.sort)
      end

      it 'preserves nil values for empty aggregateWindow buckets' do
        # Only two data points were inserted across the 2-hour timeframe,
        # so most 5-minute buckets are empty. They must surface as nil
        # (not be filtered out) so Chart.js renders real data gaps as
        # visible breaks instead of bridging them.
        house_power_series = result.house_power(:avg, :avg)

        expect(house_power_series.values).to include(nil)
      end
    end

    context 'when timeframe is a day' do
      let(:timeframe) { Timeframe.day }

      it 'returns multiple data points for daily charts' do
        expect(result).to be_a(Sensor::Data::Series)

        house_power_series = result.house_power(:avg, :avg)
        expect(house_power_series.length).to be > 1
      end
    end

    context 'when timeframe is now' do
      let(:timeframe) { Timeframe.now }

      it 'returns empty result' do
        expect(result).to eq({})
      end
    end
  end

  describe 'forecast mode (with timestamp_method and interval)' do
    subject(:series_query) do
      described_class.new(
        [:house_power],
        timeframe,
        timestamp_method: :to_time,
        interval: '15m',
      )
    end

    let(:timeframe) do
      Timeframe.new("#{Date.current + 1.day}..#{Date.current + 3.days}")
    end

    before do
      freeze_time

      influx_batch do
        # Create data at 15-minute intervals across multiple days
        96.times do |i|
          time = (Date.current + 1.day).beginning_of_day + (i * 15).minutes
          add_influx_point(
            name: Sensor::Config.measurement(:house_power),
            fields: {
              Sensor::Config.field(:house_power) =>
                (8...16).cover?(time.hour) ? 1000 : 0,
            },
            time:,
          )
        end

        48.times do |i|
          time = (Date.current + 2.days).beginning_of_day + (i * 15).minutes
          add_influx_point(
            name: Sensor::Config.measurement(:house_power),
            fields: {
              Sensor::Config.field(:house_power) =>
                (8...16).cover?(time.hour) ? 1000 : 0,
            },
            time:,
          )
        end
      end
    end

    it 'returns high-resolution timestamp data across multiple days' do
      result = series_query.call

      expect(result).to be_a(Sensor::Data::Series)

      series = result.house_power(:avg, :avg)
      expect(series).not_to be_empty

      # Should have many data points at 15-minute intervals
      timestamps = series.keys
      expect(timestamps.length).to be > 50

      # All keys should be timestamps, not dates
      expect(timestamps).to all(be_a(Time))

      # Verify 15-minute intervals (sample first few)
      intervals =
        timestamps.take(5).each_cons(2).map { |a, b| ((b - a) / 60).round }
      expect(intervals).to all(eq(15))

      # Data should span multiple days
      dates = timestamps.map(&:to_date)
      dates.uniq!
      expect(dates.length).to be >= 2
    end
  end

  describe 'forecast time-shift' do
    let(:base_day) { Date.current + 1.day }
    let(:timeframe) { Timeframe.new(base_day.to_s) }
    let(:start) { base_day.in_time_zone.change(hour: 10) }

    before { freeze_time }

    def add_point(sensor, time, value)
      add_influx_point(
        name: Sensor::Config.measurement(sensor),
        fields: {
          Sensor::Config.field(sensor) => value,
        },
        time:,
      )
    end

    context 'with only a forecast sensor' do
      subject(:series_query) do
        described_class.new(
          [:inverter_power_forecast],
          timeframe,
          timestamp_method: :to_time,
          interval: '15m',
        )
      end

      before do
        influx_batch do
          8.times do |i|
            add_point(
              :inverter_power_forecast,
              start + (i * 15).minutes,
              (i + 1) * 1000,
            )
          end
        end
      end

      it 'shifts each sample back by 7.5 minutes (half the cadence)' do
        series =
          series_query.call.inverter_power_forecast(:avg, :avg)
        expect(series).not_to be_empty

        # Without the shift, the sample stored at 10:00 would land in the
        # 10:15 bucket; the -7.5 min shift moves it into the 10:00 bucket.
        expect(series[start]).to eq(1000)
        expect(series[start + 15.minutes]).to eq(2000)
        expect(series[start + 1.hour + 45.minutes]).to eq(8000)
      end
    end

    context 'with a forecast sensor mixed with a non-forecast sensor' do
      subject(:series_query) do
        described_class.new(
          %i[inverter_power_forecast house_power],
          timeframe,
          timestamp_method: :to_time,
          interval: '15m',
        )
      end

      before do
        influx_batch do
          4.times do |i|
            time = start + (i * 15).minutes
            add_point(:inverter_power_forecast, time, (i + 1) * 1000)
            add_point(:house_power, time, (i + 1) * 500)
          end
        end
      end

      it 'shifts only the forecast stream, leaving other sensors aligned' do
        result = series_query.call
        forecast = result.inverter_power_forecast(:avg, :avg)
        house = result.house_power(:avg, :avg)

        expect(forecast[start]).to eq(1000)

        expect(house[start + 15.minutes]).to eq(500)
        expect(house[start]).to be_nil
      end
    end

    context 'when called with interpolate: true' do
      subject(:series_query) do
        described_class.new(
          [:inverter_power_forecast],
          timeframe,
          timestamp_method: :to_time,
          interval: '15m',
        )
      end

      before do
        influx_batch do
          4.times do |i|
            add_point(
              :inverter_power_forecast,
              start + (i * 15).minutes,
              (i + 1) * 1000,
            )
          end
        end
      end

      it 'bypasses the time-shift (plain interpolation query)' do
        series =
          series_query.call(interpolate: true).inverter_power_forecast(
            :avg,
            :avg,
          )
        expect(series).not_to be_empty

        expect(series[start]).to be_nil
        expect(series[start + 15.minutes]).to be_present
      end
    end
  end
end
