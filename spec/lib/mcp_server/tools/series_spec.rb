describe McpServer::Tools::Series do
  def call(**args)
    response = described_class.call(**args)
    [response.error?, response.content.first[:text]]
  end

  def series(**args)
    _error, text = call(**args)
    JSON.parse(text, symbolize_names: true)
  end

  before { freeze_time }

  describe '.call' do
    context 'with measured data and a gap' do
      before do
        influx_batch do
          # A measured 0 (e.g. battery empty) ...
          add_influx_point(
            name: Sensor::Config.measurement(:battery_soc),
            fields: {
              Sensor::Config.field(:battery_soc) => 0.0,
            },
            time: 150.minutes.ago,
          )
          # ... and a real value two hours later, leaving an empty bucket between.
          add_influx_point(
            name: Sensor::Config.measurement(:battery_soc),
            fields: {
              Sensor::Config.field(:battery_soc) => 50.0,
            },
            time: 30.minutes.ago,
          )
        end
      end

      it 'distinguishes a measured 0 from null (no data)' do
        data = series(sensors: ['battery_soc'], timeframe: 'P3H', resolution: '1h')

        values = data[:series].first[:points].pluck(:value)
        expect(values).to include(0.0) # measured zero is kept
        expect(values).to include(nil) # empty bucket stays null
      end

      it 'returns points in chronological order' do
        data = series(sensors: ['battery_soc'], timeframe: 'P3H', resolution: '1h')

        times = data[:series].first[:points].map { |p| Time.iso8601(p[:time]) }
        expect(times).to eq(times.sort)
      end
    end

    context 'with resolution selection' do
      it 'auto-selects a resolution within the point limit' do
        data = series(sensors: ['battery_soc'], timeframe: 'P7D')

        expect(data[:resolution]).to be_in(%w[1m 5m 15m 1h 1d])
        expect(data[:series].first[:points].size).to be <= 1500
      end

      it 'coarsens a too-fine resolution and reports the one actually used' do
        data = series(sensors: ['battery_soc'], timeframe: 'P30D', resolution: '1m')

        expect(data[:resolution]).not_to eq('1m')
        expect(data[:series].first[:points].size).to be <= 1500
      end

      it 'keeps a resolution that already fits' do
        data = series(sensors: ['battery_soc'], timeframe: 'P24H', resolution: '1h')

        expect(data[:resolution]).to eq('1h')
      end
    end

    context 'with a resolution finer than the sensor cadence' do
      # The forecast source only carries a sample every 15 minutes. 1m fits the
      # point cap for a single day (1440 < 1500), so the cap alone would keep
      # it; without cadence-snapping the response is a ~93% null grid.
      let(:day) { (Date.current + 1.day).to_s }

      before do
        influx_batch do
          96.times do |i|
            time = (Date.current + 1.day).beginning_of_day + (i * 15).minutes
            add_influx_point(
              name: Sensor::Config.measurement(:inverter_power_forecast),
              fields: {
                Sensor::Config.field(:inverter_power_forecast) =>
                  (8...16).cover?(time.hour) ? 1000 : 0,
              },
              time:,
            )
          end
        end
      end

      it 'snaps the resolution to the native cadence and reports it' do
        data =
          series(
            sensors: ['inverter_power_forecast'],
            timeframe: day,
            resolution: '1m',
          )

        expect(data[:resolution]).to eq('15m')
      end

      it 'does not return a mostly-null series' do
        data =
          series(
            sensors: ['inverter_power_forecast'],
            timeframe: day,
            resolution: '1m',
          )

        points = data[:series].first[:points]
        non_null = points.count { |p| !p[:value].nil? }

        # At 1m this would be ~96/1440 (7%); snapped to 15m nearly every bucket
        # carries a value.
        expect(points.size).to be < 200
        expect(non_null.fdiv(points.size)).to be > 0.8
      end
    end

    context 'with multiple sensors' do
      it 'returns one series per sensor' do
        data =
          series(
            sensors: %w[battery_soc house_power],
            timeframe: 'P6H',
            resolution: '1h',
          )

        expect(data[:series].pluck(:sensor)).to eq(%w[battery_soc house_power])
      end
    end

    # Regression: derived sensors (computed, not stored as a raw field) used to
    # return an empty series. inverter_power_total = inverter_power_1 +
    # inverter_power_2 is derived the same way as house_power_without_custom.
    context 'with a derived (calculated) sensor' do
      def seed_inverters(value1:, value2:, from:)
        influx_batch do
          (0..from).step(15).each do |minutes|
            time = minutes.minutes.ago
            add_influx_point(
              name: Sensor::Config.measurement(:inverter_power_1),
              fields: {
                Sensor::Config.field(:inverter_power_1) => value1,
              },
              time:,
            )
            add_influx_point(
              name: Sensor::Config.measurement(:inverter_power_2),
              fields: {
                Sensor::Config.field(:inverter_power_2) => value2,
              },
              time:,
            )
          end
        end
      end

      it 'returns the per-bucket sum of its inputs, not an empty series' do
        seed_inverters(value1: 100.0, value2: 200.0, from: 180)

        data =
          series(
            sensors: ['inverter_power_total'],
            timeframe: 'P3H',
            resolution: '1h',
          )

        values = data[:series].first[:points].pluck(:value).compact
        expect(values).not_to be_empty
        expect(values).to all(eq(300.0)) # mean of constant (100 + 200)
      end

      it 'agrees with get_totals that the sensor has data' do
        seed_inverters(value1: 100.0, value2: 200.0, from: 180)

        series_sum =
          series(sensors: ['inverter_power_total'], timeframe: 'P3H', resolution: '1h')
            .dig(:series, 0, :points)
            .pluck(:value)
            .compact
            .sum
        totals =
          JSON.parse(
            McpServer::Tools::Totals.call(
              timeframe: 'P3H',
              sensors: ['inverter_power_total'],
            ).content.first[:text],
            symbolize_names: true,
          )

        expect(series_sum).to be > 0
        expect(totals[:totals].first[:value]).to be > 0
      end

      it 'returns null (not 0) for a bucket whose source data is missing' do
        # Only the most recent ~40 min carry data; earlier buckets are empty.
        seed_inverters(value1: 100.0, value2: 200.0, from: 40)

        data =
          series(
            sensors: ['inverter_power_total'],
            timeframe: 'P3H',
            resolution: '1h',
          )

        values = data[:series].first[:points].pluck(:value)
        expect(values).to include(nil)   # empty bucket -> null
        expect(values).to include(300.0) # bucket with data -> derived sum
      end
    end

    context 'with an absolute date range' do
      it 'accepts the range' do
        error, = call(
          sensors: ['battery_soc'],
          timeframe: '2024-01-01..2024-01-03',
          resolution: '1d',
        )

        expect(error).to be(false)
      end
    end

    context 'with invalid input' do
      it 'rejects the now instant' do
        error, text = call(sensors: ['battery_soc'], timeframe: 'now')

        expect(error).to be(true)
        expect(text).to include('span')
      end

      it 'reports an unknown sensor' do
        error, text = call(sensors: ['nonexistent'], timeframe: 'P3H')

        expect(error).to be(true)
        expect(text).to include('Unknown or unconfigured')
      end

      it 'rejects too many sensors' do
        error, text = call(sensors: ['battery_soc'] * 21, timeframe: 'P3H')

        expect(error).to be(true)
        expect(text).to include('Too many sensors')
      end

      it 'reports an invalid timeframe' do
        error, text = call(sensors: ['battery_soc'], timeframe: 'not-a-timeframe')

        expect(error).to be(true)
        expect(text).to include('not a valid timeframe')
      end
    end
  end
end
