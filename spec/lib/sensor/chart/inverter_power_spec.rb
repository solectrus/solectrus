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
        # 3 nil minutes between 110 and 200 -- 4 min total gap, well under 15
        labels = minute_labels(6)
        result = chart.__send__(:bridge_short_gaps, labels, [100, 110, nil, nil, nil, 200])

        expect(result).to eq([100, 110, 132.5, 155.0, 177.5, 200])
      end

      it 'leaves long null runs as nil so line and area break together' do
        # 20 nil minutes between 100 and 200 -- over the 15-minute threshold
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
end
