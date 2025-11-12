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

        # Check that each time point has the expected structure
        house_power_series.each do |time, value|
          expect(time).to be_a(Time)

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
end
