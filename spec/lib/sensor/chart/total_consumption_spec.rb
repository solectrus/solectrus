describe Sensor::Chart::TotalConsumption do
  subject(:chart) { described_class.new(timeframe:) }

  describe 'with excluded custom sensors' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    let(:env) do
      {
        'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_SENSOR_HEATPUMP_POWER' => 'pv:heatpump_power',
        'INFLUX_SENSOR_CUSTOM_POWER_01' => 'consumer:power_01',
        'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'CUSTOM_POWER_01',
      }
    end

    before do
      Sensor::Config.setup(env)

      create_summary(
        date: '2025-03-03',
        values: [
          [:house_power, :sum, 20_000], # already reduced by custom_power_01
          [:heatpump_power, :sum, 5_000],
          [:custom_power_01, :sum, 8_000],
        ],
      )
    end

    after { Sensor::Config.setup(ENV) }

    it 'includes the excluded custom sensor as its own segment' do
      dataset_ids = chart.data[:datasets].map { |d| d[:id].to_sym }

      expect(dataset_ids).to include(:custom_power_01)
    end

    it 'stacks all segments together so they sum to total_consumption' do
      datasets = chart.data[:datasets]

      expect(datasets.pluck(:stack).uniq).to eq(['TotalConsumption'])
    end

    it 'places the excluded custom sensor right after house_power' do
      ids = chart.data[:datasets].map { |d| d[:id].to_sym }

      expect(ids.index(:custom_power_01)).to eq(ids.index(:house_power) + 1)
    end

    it 'colors the excluded custom sensor with the house color (matching its segment)' do
      dataset = chart.data[:datasets].find { |d| d[:id] == 'custom_power_01' }

      expect(dataset[:colorClass]).to eq(Sensor::Registry[:house_power].color_background)
    end
  end

  describe 'gap bridging' do
    let(:timeframe) { Timeframe.new('2025-03-03') }
    let(:chart) { described_class.new(timeframe:) }

    # Simulate aggregateWindow output: a chronological array of values, some of
    # which are nil (empty buckets), on a 1-minute label grid. The bridge limit
    # is derived from the label spacing, not from #interval.
    def pad(values, sensor_name: :house_power)
      labels = values.each_index.map { |i| (i * 1.minute).in_milliseconds }
      item = { sensor_name:, labels:, data: values.dup }
      chart.__send__(:grid_aligned_values, labels, item)
    end

    it 'bridges short house_power outages by interpolating across the gap' do
      # 4-minute gap at 1m interval - below the 5min limit
      result = pad([100, 110, 120, nil, nil, nil, 130, 140])
      expect(result).to eq([100, 110, 120, 122.5, 125, 127.5, 130, 140])
    end

    it 'fills long house_power outages with zero' do
      # 20 nil samples at 1m interval = 21min > 5min limit
      result = pad([100, 110, 120, *[nil] * 20, 130, 140])
      expect(result.slice(3, 20)).to all(eq(0))
    end

    # A trailing null run has no right-hand anchor to interpolate against, so
    # without fill_trailing_edge house_power would drop to zero at the right
    # edge - the artifact issue #5766 is about.
    it 'bridges a short house_power outage at the right edge' do
      expect(pad([100, 110, 120, nil, nil])).to eq([100, 110, 120, 120, 120])
    end

    # These are subtracted from house_power, so a nil bucket means "no power".
    # Bridging would carry a value house_power has not been reduced by.
    it 'never bridges sensors subtracted from house_power' do
      %i[heatpump_power wallbox_power custom_power_01].each do |name|
        expect(pad([100, nil, nil, 100], sensor_name: name)).to eq([100, 0, 0, 100])
      end
    end

    it 'keeps a trailing gap at 0 for sensors subtracted from house_power' do
      %i[heatpump_power wallbox_power custom_power_01].each do |name|
        expect(pad([100, 100, nil, nil], sensor_name: name)).to eq([100, 100, 0, 0])
      end
    end
  end

  describe 'sensors without any data in the timeframe' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    let(:env) do
      {
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_SENSOR_HEATPUMP_POWER' => 'pv:heatpump_power',
      }
    end

    before do
      Sensor::Config.setup(env)

      # heatpump_power is configured, but never reported in this week.
      create_summary(
        date: '2025-03-03',
        values: [[:house_power, :sum, 20_000]],
      )
    end

    after { Sensor::Config.setup(ENV) }

    # #fill_gaps_with_zero? would otherwise turn the all-nil aligned series
    # into a full-length row of zeros, so the tooltip would report a measured
    # "0 W" for every bucket of a sensor that measured nothing at all.
    it 'drops the dataset instead of rendering it as a flat zero series' do
      dataset_ids = chart.data[:datasets].map { |d| d[:id].to_sym }

      expect(dataset_ids).not_to include(:heatpump_power)
    end
  end
end
