describe Sensor::Chart::InverterPower do
  describe '#inverter_power' do
    let(:chart) { described_class.new(timeframe:) }

    context 'when timeframe is day' do
      let(:timeframe) { Timeframe.new('2025-03-03') }

      it 'calculates energy using integration (Power × Time)' do
        # Simulate 5-minute power data: 1000 W + 2000 W for 5 min each
        series = Sensor::Data::Series.new(
          {
            %i[inverter_power avg avg] => {
              Time.zone.local(2025, 3, 3, 10, 0, 0) => 1000,
              Time.zone.local(2025, 3, 3, 10, 5, 0) => 2000,
              Time.zone.local(2025, 3, 3, 10, 10, 0) => 3000,
            },
          },
          timeframe: timeframe,
        )

        allow(chart).to receive(:series).and_return(series)

        # EnergyCalculator: 1000 W * 5 min + 2000 W * 5 min = 250 Wh
        expect(chart.inverter_power).to eq(250.0)
      end

      it 'ignores nil values from the shared timestamp grid' do
        # Forecast is stored hourly but shares the 5-min timestamp grid with
        # the actual sensor - intermediate slots are nil and must not dilute
        # the integration.
        forecast_series = {
          Time.zone.local(2025, 3, 3, 10, 0, 0) => 1000,
          Time.zone.local(2025, 3, 3, 10, 5, 0) => nil,
          Time.zone.local(2025, 3, 3, 10, 10, 0) => nil,
          Time.zone.local(2025, 3, 3, 10, 55, 0) => nil,
          Time.zone.local(2025, 3, 3, 11, 0, 0) => 2000,
          Time.zone.local(2025, 3, 3, 11, 5, 0) => nil,
          Time.zone.local(2025, 3, 3, 12, 0, 0) => 1500,
        }
        series = Sensor::Data::Series.new(
          { %i[inverter_power_forecast avg avg] => forecast_series },
          timeframe: timeframe,
        )

        allow(chart).to receive(:series).and_return(series)

        # After dropping nils: 1000 W * 1h + 2000 W * 1h = 3000 Wh
        expect(chart.inverter_power_forecast).to eq(3000.0)
      end
    end

    context 'with sparse data (nil values in series)' do
      let(:timeframe) { Timeframe.new('2025-03-03') }

      def minute_labels(count, start_minute: 0)
        Array.new(count) do |i|
          Time.zone.local(2025, 3, 3, 10, start_minute + i, 0).to_i * 1000
        end
      end

      it 'bridges short null runs with linear interpolation' do
        # 3 nil minutes between 110 and 200 -- 4 min total gap, under the
        # SPAN_GAPS_MS floor (5 min). Only 2 real samples, so the adaptive
        # cadence detection stays out and the floor is the binding limit.
        labels = minute_labels(6)
        result = chart.__send__(:bridge_short_gaps, labels, [100, 110, nil, nil, nil, 200])

        expect(result).to eq([100, 110, 132.5, 155.0, 177.5, 200])
      end

      it 'leaves long null runs as nil so line and area break together' do
        # 20 nil minutes between 100 and 200 -- well over the 5-min floor
        gap = [nil] * 20
        labels = minute_labels(gap.size + 2)
        result = chart.__send__(:bridge_short_gaps, labels, [100, *gap, 200])

        expect(result).to eq([100, *gap, 200])
      end

      it 'leaves leading nulls untouched (no prior value to anchor)' do
        labels = minute_labels(4)
        result = chart.__send__(:bridge_short_gaps, labels, [nil, nil, 100, 110])

        expect(result).to eq([nil, nil, 100, 110])
      end

      it 'leaves trailing nulls untouched (no following value to anchor)' do
        labels = minute_labels(4)
        result = chart.__send__(:bridge_short_gaps, labels, [100, 110, nil, nil])

        expect(result).to eq([100, 110, nil, nil])
      end
    end

    context 'when timeframe is now' do
      let(:timeframe) { Timeframe.now }

      it 'calculates energy using integration (Power × Time)' do
        now = Time.current
        # Simulate 5-minute interval data: 1200 W for 5 min = 100 Wh
        series = Sensor::Data::Series.new(
          {
            %i[inverter_power avg avg] => {
              now => 1200,
              now + 5.minutes => 1200,
            },
          },
          timeframe: timeframe,
        )

        allow(chart).to receive(:series).and_return(series)

        # EnergyCalculator: 1200 W for 5 minutes = 100 Wh
        expect(chart.inverter_power).to eq(100.0)
      end
    end
  end

  describe '#sunrise / #sunset' do
    let(:chart) { described_class.new(timeframe:) }
    let(:timeframe) { Timeframe.new('2025-03-03') }

    it 'returns first/last forecast bucket > 0 (handles any cadence)' do
      # Mixed cadence: forecast values present at 06:00, 06:30, 19:30; others nil
      forecast_series = {
        Time.zone.local(2025, 3, 3, 5, 30, 0) => 0,
        Time.zone.local(2025, 3, 3, 6, 0, 0) => 50,
        Time.zone.local(2025, 3, 3, 6, 30, 0) => 200,
        Time.zone.local(2025, 3, 3, 12, 0, 0) => nil,
        Time.zone.local(2025, 3, 3, 19, 30, 0) => 80,
        Time.zone.local(2025, 3, 3, 20, 0, 0) => 0,
      }
      series = Sensor::Data::Series.new(
        { %i[inverter_power_forecast avg avg] => forecast_series },
        timeframe: timeframe,
      )
      allow(chart).to receive(:series).and_return(series)

      expect(chart.sunrise).to eq(Time.zone.local(2025, 3, 3, 6, 0, 0))
      expect(chart.sunset).to eq(Time.zone.local(2025, 3, 3, 19, 30, 0))
    end

    it 'returns nil when no forecast data is available' do
      series =
        Sensor::Data::Series.new(
          { %i[inverter_power avg avg] => {} },
          timeframe: timeframe,
        )
      allow(chart).to receive(:series).and_return(series)

      expect(chart.sunrise).to be_nil
      expect(chart.sunset).to be_nil
    end
  end

  describe 'variability band' do
    let(:chart) { described_class.new(timeframe:) }

    context 'when the timeframe counts hours back from now' do
      let(:timeframe) { Timeframe.new('P24H') }

      it 'leaves the band out' do
        expect(chart.chart_sensor_names).not_to include(:inverter_power_forecast_min)
      end
    end

    context 'when the day is over' do
      let(:timeframe) { Timeframe.new('2025-03-03') }

      it 'leaves the band out' do
        expect(chart.chart_sensor_names).not_to include(:inverter_power_forecast_min)
      end
    end

    context 'when the day is today' do
      let(:timeframe) { Timeframe.new(Date.current.iso8601) }
      let(:start) { Date.current.beginning_of_day.in_time_zone }
      let(:datasets) { chart.data[:datasets] }

      # The actual power comes every 5 minutes up to now, the forecast
      # every 15 minutes for the whole day, on the same 5-minute grid
      def series
        actual = (0...(12 * 12)).to_h { |i| [start + (i * 5).minutes, 500.0] }
        grid = (0...(24 * 12)).map { |i| start + (i * 5).minutes }
        band = lambda do |factor|
          grid.index_with do |t|
            next if (t.min % 15).nonzero?

            t.hour.between?(8, 16) ? factor * 1000.0 : 0.0
          end
        end

        Sensor::Data::Series.new(
          {
            %i[inverter_power avg avg] => actual,
            %i[inverter_power_forecast avg avg] => band.call(1),
            %i[inverter_power_forecast_min avg avg] => band.call(0.8),
            %i[inverter_power_forecast_max avg avg] => band.call(1.2),
          },
          timeframe: timeframe,
        )
      end

      before { travel_to(start + 12.hours) }

      it 'shows the band after now, bridging the finer grid' do
        allow(chart).to receive(:series).and_return(series)

        lower = datasets.index { |d| d[:id] == 'inverter_power_forecast_min' }
        upper = datasets.find { |d| d[:id] == 'inverter_power_forecast_max' }
        labels = chart.data[:labels]
        afternoon = labels.index((start + 14.hours).to_i * 1000)

        expect(upper[:fill]).to eq(lower)
        expect(upper[:data][afternoon]).to eq(1200)
        # A numeric spanGaps would not bridge the empty 5-minute points
        expect(upper[:spanGaps]).to be(true)
      end

      # The last actual point is at 11:55, between two forecast points
      it 'begins the band where the actual generation ends' do
        allow(chart).to receive(:series).and_return(series)

        lower = datasets.find { |d| d[:id] == 'inverter_power_forecast_min' }
        upper = datasets.find { |d| d[:id] == 'inverter_power_forecast_max' }
        last = chart.data[:labels].index((start + 11.hours + 55.minutes).to_i * 1000)

        expect(upper[:data][...last]).to all(be_nil)
        expect(lower[:data][...last]).to all(be_nil)
        expect([lower[:data][last], upper[:data][last]]).to eq([800, 1200])
      end

      # The band narrows to the forecast at 17:00
      it 'draws the forecast as a line without a fill' do
        allow(chart).to receive(:series).and_return(series)

        lower = datasets.find { |d| d[:id] == 'inverter_power_forecast_min' }
        forecast = datasets.find { |d| d[:id] == 'inverter_power_forecast' }
        labels = chart.data[:labels]
        band_end = labels.index((start + 17.hours).to_i * 1000)

        expect(lower[:data].rindex { |value| value }).to eq(band_end)
        expect(forecast[:fill]).to be(false)
      end
    end
  end

  describe 'stacked view' do
    let(:chart) { described_class.new(timeframe: Timeframe.day) }

    before { allow(chart).to receive(:stackable?).and_return(true) }

    it 'hatches the rest of today with the dashed edge of the forecast' do
      sensor = Sensor::Registry[:inverter_power_forecast]
      style = chart.__send__(:style_for_sensor, sensor)

      expect(style).to include(
        hatchFill: true,
        borderDash: [6, 4],
        contrastLine: true,
        hideZeroSegments: true,
      )
    end
  end
end
