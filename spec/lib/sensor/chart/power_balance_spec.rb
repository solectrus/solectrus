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

  describe 'when no sensor has data' do
    let(:timeframe) { Timeframe.new('2025-03-03') }

    it 'returns nil for data' do
      expect(chart.data).to be_nil
    end
  end
end
