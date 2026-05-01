describe Sensor::Chart::PowerBalance do
  subject(:chart) { described_class.new(timeframe:) }

  describe 'basic attributes' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    it 'returns localized label' do
      expect(chart.label).to eq(I18n.t('charts.balance'))
    end

    it 'returns :other as menu_group' do
      expect(chart.menu_group).to eq(:other)
    end
  end

  describe 'with week timeframe' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    before do
      create_summary(
        date: '2025-03-03',
        values: [
          [:grid_import_power, :sum, 10_000],
          [:grid_export_power, :sum, 20_000],
          [:inverter_power, :sum, 25_000],
          [:house_power, :sum, 30_000],
        ],
      )

      create_summary(
        date: '2025-03-04',
        values: [
          [:grid_import_power, :sum, 15_000],
          [:grid_export_power, :sum, 10_000],
          [:inverter_power, :sum, 20_000],
          [:house_power, :sum, 35_000],
        ],
      )
    end

    it 'returns bar chart type for non-short timeframes' do
      expect(chart.type).to eq('bar')
    end

    it 'excludes unconfigured sensors from datasets' do
      allow(Sensor::Config)
        .to receive(:exists?)
        .and_call_original
      allow(Sensor::Config)
        .to receive(:exists?)
        .with(:battery_charging_power)
        .and_return(false)

      data = chart.data
      dataset_ids = data[:datasets].map { |dataset| dataset[:id].to_sym }

      expect(dataset_ids).not_to include(:battery_charging_power)
    end

    it 'excludes sensors without data from datasets' do
      dataset_ids = chart.data[:datasets].map { |d| d[:id].to_sym }

      # battery_discharging has no summary data, so it is excluded
      expect(dataset_ids).not_to include(:battery_discharging_power)
    end

    it 'shows legend' do
      options = chart.options

      expect(options[:plugins][:legend][:display]).to be(true)
      expect(options[:plugins][:legend][:position]).to eq('top')
    end

    it 'has stacked axes' do
      options = chart.options

      expect(options[:scales][:x][:stacked]).to be(true)
      expect(options[:scales][:y][:stacked]).to be(true)
    end
  end

  describe 'with day timeframe' do
    let(:timeframe) { Timeframe.new('2025-03-03') }

    it 'returns line chart type for short timeframes' do
      expect(chart.type).to eq('line')
    end
  end

  describe 'stacking logic' do
    context 'with week timeframe' do
      let(:timeframe) { Timeframe.new('2025-W10') }

      before do
        create_summary(
          date: '2025-03-03',
          values: [
            [:grid_import_power, :sum, 10_000],
            [:grid_export_power, :sum, 20_000],
            [:inverter_power, :sum, 25_000],
            [:house_power, :sum, 30_000],
          ],
        )
      end

      it 'assigns a single stack for bar charts' do
        datasets = chart.data[:datasets]
        expect(datasets).not_to be_empty
        datasets.each do |dataset|
          expect(dataset[:stack]).to eq('combined')
        end
      end
    end

    context 'with day timeframe' do
      let(:timeframe) { Timeframe.new('2025-03-03') }

      before do
        base_time = Time.zone.local(2025, 3, 3, 12, 0, 0)

        influx_batch do
          Sensor::Chart::PowerBalance::DATA_SENSOR_NAMES.each_with_index do |name, index|
            next unless Sensor::Config.exists?(name)

            measurement = public_send("measurement_#{name}")
            field = public_send("field_#{name}")

            add_influx_point(
              name: measurement,
              fields: { field => index + 1000 },
              time: base_time,
            )
            add_influx_point(
              name: measurement,
              fields: { field => index + 1100 },
              time: base_time + 1.hour,
            )
          end
        end
      end

      it 'assigns source stack to inverter, battery_discharging, and grid_import' do
        datasets = chart.data[:datasets].index_by { |dataset| dataset[:id].to_sym }
        %i[inverter_power battery_discharging_power grid_import_power].each do |name|
          dataset = datasets[name]
          next unless dataset

          expect(dataset[:stack]).to eq('source')
        end
      end

      it 'assigns usage stack to house, heatpump, wallbox, battery_charging, and grid_export' do
        usage_sensors =
          %i[
            house_power
            heatpump_power
            wallbox_power
            battery_charging_power
            grid_export_power
          ]
        datasets = chart.data[:datasets].index_by { |dataset| dataset[:id].to_sym }
        usage_sensors.each do |name|
          dataset = datasets[name]
          next unless dataset

          expect(dataset[:stack]).to eq('usage')
        end
      end

      it 'sets fill to origin for first sensor in each stack' do
        datasets = chart.data[:datasets]
        source = datasets.select { |d| d[:stack] == 'source' }
        usage = datasets.select { |d| d[:stack] == 'usage' }

        expect(source.first[:fill]).to eq('origin') if source.any?
        expect(usage.first[:fill]).to eq('origin') if usage.any?
      end

      it 'sets fill to -1 for subsequent sensors in each stack' do
        datasets = chart.data[:datasets]
        source = datasets.select { |d| d[:stack] == 'source' }
        usage = datasets.select { |d| d[:stack] == 'usage' }

        source.drop(1).each { |d| expect(d[:fill]).to eq('-1') }
        usage.drop(1).each { |d| expect(d[:fill]).to eq('-1') }
      end

      it 'contains no nil values in any dataset' do
        chart.data[:datasets].each do |dataset|
          expect(dataset[:data]).to all(be_a(Numeric)),
                                      "#{dataset[:id]} contains nil values"
        end
      end
    end
  end

  describe 'gap bridging' do
    let(:timeframe) { Timeframe.new('2025-03-03') }
    let(:chart) { described_class.new(timeframe:).tap { |c| c.interval = 1.minute } }

    # Simulate aggregateWindow output: a chronological array of values,
    # some of which are nil (empty buckets). The chart pads them so the
    # stacked area renders with numeric values everywhere.
    def pad(values, sensor_name: :inverter_power)
      items = [{ sensor_name:, data: values.dup }]
      chart.__send__(:pad_nil_values!, items)
      items.first[:data]
    end

    it 'bridges short outages with the last known value' do
      # 5-minute gap (single nil cluster) at 1m interval - well below 15min
      result = pad([100, 110, 120, nil, nil, nil, 130, 140])
      expect(result).to eq([100, 110, 120, 120, 120, 120, 130, 140])
    end

    it 'fills long outages with zero' do
      # 20 nil samples at 1m interval = 20min > 15min threshold
      gap = [nil] * 20
      result = pad([100, 110, 120, *gap, 130, 140])
      expect(result.slice(3, 20)).to all(eq(0))
    end

    it 'fills leading nils (no prior value) with zero' do
      result = pad([nil, nil, 100, 110])
      expect(result).to eq([0, 0, 100, 110])
    end

    context 'with sensors excluded from house_power' do
      let(:env) do
        {
          'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
          'INFLUX_SENSOR_HEATPUMP_POWER' => 'pv:heatpump_power',
          'INFLUX_SENSOR_WALLBOX_POWER' => 'pv:wallbox_power',
          'INFLUX_SENSOR_CUSTOM_POWER_01' => 'consumer:power_01',
          'INFLUX_EXCLUDE_FROM_HOUSE_POWER' =>
            'CUSTOM_POWER_01,HEATPUMP_POWER,WALLBOX_POWER',
        }
      end

      before { Sensor::Config.setup(env) }
      after { Sensor::Config.setup(ENV) }

      # The calculate block treats nil as 0 (no subtraction from
      # house_power). Bridging here would carry forward a value that
      # house_power has not been reduced by - double-counting the
      # excluded sensor in the stacked chart (issue #5517).
      it 'fills nil with 0 for every excluded sensor' do
        %i[custom_power_01 heatpump_power wallbox_power].each do |name|
          expect(pad([100, nil, nil, 100], sensor_name: name)).to eq(
            [100, 0, 0, 100],
          )
        end
      end
    end

    context 'when wallbox_power is NOT excluded from house_power' do
      let(:env) do
        {
          'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
          'INFLUX_SENSOR_WALLBOX_POWER' => 'pv:wallbox_power',
        }
      end

      before { Sensor::Config.setup(env) }
      after { Sensor::Config.setup(ENV) }

      it 'still bridges short outages' do
        result = pad([100, nil, nil, 100], sensor_name: :wallbox_power)
        expect(result).to eq([100, 100, 100, 100])
      end
    end
  end

  describe 'with excluded custom sensors' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    let(:env) do
      {
        'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_SENSOR_GRID_IMPORT_POWER' => 'pv:grid_import_power',
        'INFLUX_SENSOR_GRID_EXPORT_POWER' => 'pv:grid_export_power',
        'INFLUX_SENSOR_CUSTOM_POWER_01' => 'consumer:power_01',
        'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'CUSTOM_POWER_01',
      }
    end

    before do
      Sensor::Config.setup(env)

      create_summary(
        date: '2025-03-03',
        values: [
          [:grid_import_power, :sum, 10_000],
          [:grid_export_power, :sum, 5_000],
          [:inverter_power, :sum, 25_000],
          [:house_power, :sum, 20_000],
          [:custom_power_01, :sum, 8_000],
        ],
      )
    end

    it 'includes excluded custom sensor in datasets' do
      dataset_ids = chart.data[:datasets].map { |d| d[:id].to_sym }

      expect(dataset_ids).to include(:custom_power_01)
    end

    it 'negates excluded custom sensor values (consumption)' do
      dataset =
        chart.data[:datasets].find { |d| d[:id] == 'custom_power_01' }

      expect(dataset[:data].compact).to all(be_negative)
    end

    it 'places excluded custom sensor in usage stack for line charts' do
      line_chart = described_class.new(timeframe: Timeframe.new('2025-03-03'))

      influx_batch do
        base_time = Time.zone.local(2025, 3, 3, 12, 0, 0)
        add_influx_point(
          name: 'pv',
          fields: { 'inverter_power' => 5000 },
          time: base_time,
        )
        add_influx_point(
          name: 'consumer',
          fields: { 'power_01' => 1000 },
          time: base_time,
        )
      end

      data = line_chart.data
      custom_dataset =
        data[:datasets].find { |d| d[:id] == 'custom_power_01' }

      expect(custom_dataset[:stack]).to eq('usage')
    end
  end

  describe 'when no sensor has data' do
    let(:timeframe) { Timeframe.new('2025-03-03') }

    it 'returns nil for data' do
      expect(chart.data).to be_nil
    end
  end
end
