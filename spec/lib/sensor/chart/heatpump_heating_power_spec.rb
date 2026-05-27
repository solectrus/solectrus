describe Sensor::Chart::HeatpumpHeatingPower do
  let(:chart) { described_class.new(timeframe:) }
  let(:timeframe) { Timeframe.new('2024-04-19') }

  before { stub_feature(:heatpump, :power_splitter) }

  # Build a Sensor::Data::Series stubbed onto the chart. Both arrays share
  # the same 5-min bucket grid; the length determines how many buckets are
  # emitted.
  def stub_series(heating:, grid: [])
    ts = Array.new(heating.size) { |i| Time.zone.local(2024, 4, 19, 0, 0) + (i * 5).minutes }
    raw = {}
    raw[%i[heatpump_heating_power avg avg]] = ts.zip(heating).to_h
    raw[%i[heatpump_power_grid avg avg]] = ts.zip(grid).to_h if grid.any?
    series = Sensor::Data::Series.new(raw, timeframe:)
    allow(chart).to receive(:series).and_return(series)
  end

  describe '#transform_data' do
    it 'clamps component values to heating_power when both are present' do
      stub_series(
        heating: [800.0, 800.0, 800.0, 800.0],
        grid: [100, 200, 300, 400],
      )

      result = chart.__send__(
        :transform_data,
        [100, 200, 300, 400],
        :heatpump_power_grid,
      )
      expect(result).to eq([100, 200, 300, 400])
    end

    it 'returns 0 when heating_power is explicitly zero (heat pump off)' do
      stub_series(
        heating: [800.0, 0, 0, 800.0],
        grid: [100, 50, 50, 200],
      )

      result = chart.__send__(
        :transform_data,
        [100, 50, 50, 200],
        :heatpump_power_grid,
      )
      expect(result).to eq([100, 0, 0, 200])
    end

    it 'returns 0 when heating is on but the component value is missing' do
      stub_series(
        heating: [800.0, 800.0, 800.0, 800.0],
        grid: [100, nil, 200, 300],
      )

      result = chart.__send__(
        :transform_data,
        [100, nil, 200, 300],
        :heatpump_power_grid,
      )
      expect(result).to eq([100, 0, 200, 300])
    end

    it 'preserves component resolution across heating-power gaps within the bridge window' do
      # Sparse hourly heating_power on a 5-min grid (3 hours, 4 anchors).
      # Adaptive cadence detection sees 60 min spacing and widens the
      # bridge to 2 h, so heating_power is interpolated across every
      # interior bucket. Grid keeps its native 5-min cadence (no two
      # adjacent values are equal) and survives the clamp.
      heating = Array.new(37, nil)
      [0, 12, 24, 36].each { |i| heating[i] = 800.0 }
      grid = Array.new(37) { |i| i + 100 } # 100, 101, ..., 136

      stub_series(heating: heating, grid: grid)
      result = chart.__send__(:transform_data, grid, :heatpump_power_grid)

      # Every component value clamps to itself (all well below 800 W),
      # so the dense grid signal survives in full -- not downsampled.
      expect(result).to eq(grid)
    end

    it 'leaves nil when the heating-power gap exceeds the bridge window' do
      # Two hourly anchors with a 6 h gap between them. Cadence detection
      # is inactive (only 2 samples), the SPAN_GAPS_MS floor (5 min) wins,
      # and the 6 h gap exceeds it -- so heating_power stays nil there and
      # the component output is nil too (rendered as a real outage).
      heating = Array.new(73, nil)
      heating[0] = 800.0
      heating[72] = 800.0
      grid = Array.new(73, 100)

      stub_series(heating: heating, grid: grid)
      result = chart.__send__(:transform_data, grid, :heatpump_power_grid)

      expect(result.first).to eq(100)
      expect(result[72]).to eq(100)
      expect(result[1..71]).to all(be_nil)
    end
  end

  # End-to-end gap handling for the case from
  # https://solectrus.localhost/heatpump/heatpump_heating_power/2024-04-19
  # -- hourly samples landed on a 5-min bucket grid. Adaptive bridging in
  # Base detects the hourly cadence and widens the bridge to 2h so the
  # stacked area stays continuous.
  describe '#process_gaps' do
    def labels(count)
      Array.new(count) { |i| i * 5.minutes.in_milliseconds }
    end

    it 'bridges hourly gaps via the adaptive bridge limit' do
      # 4 hourly samples spread across 3 hours = 37 buckets. Cadence
      # detection sees a 60 min median spacing and widens the limit to
      # 2 h, so all 33 interior nil buckets are linearly interpolated.
      values = Array.new(37, nil)
      [0, 12, 24, 36].each { |i| values[i] = 800.0 }

      result = chart.__send__(:process_gaps, labels(37), values)

      expect(result).to all(eq(800.0))
    end

    it 'leaves outages longer than the adaptive limit as visible breaks' do
      # 4 hourly samples with a 3 h dropout in the middle: 00:00, 01:00,
      # [gap of 3 h], 04:00, 05:00. Median spacing = 60 min, limit = 2 h.
      # The 3 h gap is wider than the limit and stays nil.
      values = Array.new(61, nil)
      [0, 12, 48, 60].each { |i| values[i] = 800.0 }

      result = chart.__send__(:process_gaps, labels(61), values)

      # 1 h gap on either side: bridged
      expect(result[1..11]).to all(eq(800.0))
      expect(result[49..59]).to all(eq(800.0))
      # 3 h gap in the middle: left as a break
      expect(result[13..47]).to all(be_nil)
    end

    it 'keeps an explicit 0 (off-phase) as 0' do
      result = chart.__send__(:process_gaps, labels(5), [800.0, 0, 0, 0, 800.0])
      expect(result).to eq([800.0, 0, 0, 0, 800.0])
    end
  end

  # Aggregated timeframes use SQL group_by so the series has Date keys.
  # Date doesn't respond to #to_i, so the bridging path (which builds ms
  # labels) must be skipped for these timeframes -- otherwise the whole
  # view raises NoMethodError on render.
  describe 'aggregated timeframes (week / month / year)' do
    let(:timeframe) { Timeframe.new('2024-W16') }

    it 'does not raise NoMethodError when building data with Date keys' do
      # SQL aggregations for week timeframes use :sum/:sum for power sensors.
      raw = {
        %i[heatpump_heating_power sum sum] => {
          Date.new(2024, 4, 15) => 19_200,
          Date.new(2024, 4, 16) => 19_200,
          Date.new(2024, 4, 17) => nil,
          Date.new(2024, 4, 18) => 19_200,
        },
      }
      series = Sensor::Data::Series.new(raw, timeframe:)
      allow(chart).to receive(:series).and_return(series)

      expect { chart.__send__(:bridged_heating_power) }.not_to raise_error
    end
  end
end
