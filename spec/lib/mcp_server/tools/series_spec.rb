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

      it 'reports coarsened: false when the requested resolution is kept' do
        data = series(sensors: ['battery_soc'], timeframe: 'P24H', resolution: '1h')

        expect(data[:coarsened]).to be(false)
      end

      it 'reports coarsened: true when a too-fine resolution is downgraded' do
        data = series(sensors: ['battery_soc'], timeframe: 'P30D', resolution: '1m')

        expect(data[:coarsened]).to be(true)
      end
    end

    context 'with the point budget shared across multiple sensors' do
      # A single day at 1m is 1440 points - within the cap for ONE sensor, but
      # three sensors at 1m would be 4320, overflowing the client. The budget is
      # global, so the resolution coarsens until the WHOLE payload fits.
      let(:sensors) { %w[house_power inverter_power grid_import_power] }
      let(:day) { Date.current.to_s }

      it 'coarsens so the total point count stays within the cap' do
        data = series(sensors:, timeframe: day)

        total_points = data[:series].sum { |s| s[:points].size }
        expect(total_points).to be <= 1500
      end

      it 'does not keep 1m for three sensors on a single day' do
        data = series(sensors:, timeframe: day, resolution: '1m')

        expect(data[:resolution]).not_to eq('1m')
        expect(data[:coarsened]).to be(true)
      end
    end

    context 'with a resolution finer than a forecast window' do
      # Forecast providers carry one sample per 15 minutes at the finest. 1m
      # fits the point cap for a single day (1440 < 1500), so the cap alone
      # would keep it and the response would be a ~93% null grid.
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

      it 'lifts the resolution to the forecast window and reports it' do
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

        # At 1m this would be ~96/1440 (7%); at 15m nearly every bucket carries
        # a value.
        expect(points.size).to be < 200
        expect(non_null.fdiv(points.size)).to be > 0.8
      end
    end

    # Regression: an event-based sensor (a coffee machine writing only on load
    # change) had its cadence estimated from the aggregated grid. That estimate
    # grew with the bucket size - samples merge, gaps widen - so the coarser
    # the request, the coarser the estimate and the coarser the answer: 5m came
    # back as 5m, but 15m and 1h both collapsed into 1d.
    context 'with a sparse, event-based sensor' do
      let(:day) { (Date.current - 1.day).to_s }
      let(:resolutions) { %w[1m 5m 15m 1h] }
      # Six brew cycles spread over the day, each written as two points (on,
      # off) four minutes apart.
      let(:brews) { [7.hours, 7.hours + 20.minutes, 9.hours, 12.hours + 30.minutes, 15.hours + 10.minutes, 18.hours] }
      let(:cycle) { { 0.minutes => 1312.3, 4.minutes => 0.0 } }

      before do
        base = (Date.current - 1.day).beginning_of_day

        influx_batch do
          brews.each do |offset|
            cycle.each do |delay, value|
              add_influx_point(
                name: Sensor::Config.measurement(:custom_power_12),
                fields: {
                  Sensor::Config.field(:custom_power_12) => value,
                },
                time: base + offset + delay,
              )
            end
          end
        end
      end

      def resolution_for(requested)
        series(
          sensors: ['custom_power_12'],
          timeframe: day,
          resolution: requested,
        )[:resolution]
      end

      it 'never answers a coarser request with a coarser resolution' do
        # Here in its strongest form: every requested resolution is honoured
        # verbatim, because nothing about this sensor sets a floor.
        expect(resolutions.map { |requested| resolution_for(requested) }).to eq(resolutions)
      end

      it 'returns the full grid including empty buckets by default' do
        points =
          series(
            sensors: ['custom_power_12'],
            timeframe: day,
            resolution: '15m',
          ).dig(:series, 0, :points)

        expect(points.size).to eq(96)
        expect(points.pluck(:value)).to include(nil)
      end

      it 'omits exactly the empty buckets with include_nulls: false' do
        args = { sensors: ['custom_power_12'], timeframe: day, resolution: '15m' }
        full = series(**args).dig(:series, 0, :points)
        compact = series(**args, include_nulls: false).dig(:series, 0, :points)

        # Same points, same timestamps - only the empty ones are gone.
        expect(compact).to eq(full.reject { |point| point[:value].nil? })
        expect(compact.size).to eq(6)
      end

      it 'keeps every event visible at the resolution it returns' do
        points =
          series(
            sensors: ['custom_power_12'],
            timeframe: day,
            resolution: '15m',
          ).dig(:series, 0, :points)

        expect(points.count { |point| !point[:value].nil? }).to eq(6)
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

    context 'with the unsupported sum aggregation' do
      # get_series no longer offers "sum": a summed coarse series is not an
      # energy integration, so it is rejected for every sensor and the client
      # is pointed to get_totals for period totals.
      it 'rejects sum and points to get_totals' do
        error, text =
          call(
            sensors: ['inverter_power_forecast'],
            timeframe: 'P2D',
            resolution: '1d',
            aggregation: 'sum',
          )

        expect(error).to be(true)
        expect(text).to include('get_totals')
      end

      it 'rejects sum even on a non-power sensor' do
        error, = call(sensors: ['battery_soc'], timeframe: 'P2D', aggregation: 'sum')

        expect(error).to be(true)
      end

      it 'still allows mean/min/max' do
        %w[mean min max].each do |aggregation|
          error, =
            call(
              sensors: ['inverter_power_forecast'],
              timeframe: 'P2D',
              resolution: '1d',
              aggregation:,
            )

          expect(error).to be(false), "expected #{aggregation} to be allowed"
        end
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

      it 'rejects sensors with no curve (money, chart-only composites)' do
        money_error, money_text = call(sensors: ['solar_price'], timeframe: 'P2D')
        expect(money_error).to be(true)
        expect(money_text).to include('get_totals')

        balance_error, = call(sensors: ['power_balance'], timeframe: 'P2D')
        expect(balance_error).to be(true)
      end
    end
  end

  describe 'value normalization' do
    it 'collapses a signed negative zero to a plain 0.0' do
      result = McpServer::Tools::Series::Points.normalize_value(-0.0)

      # -0.0.to_json would serialise as "-0.0"; a normalized 0.0 must not.
      expect(result.to_json).to eq('0.0')
    end

    it 'leaves non-zero values and null untouched' do
      expect(McpServer::Tools::Series::Points.normalize_value(42.5)).to eq(42.5)
      expect(McpServer::Tools::Series::Points.normalize_value(nil)).to be_nil
    end
  end
end
