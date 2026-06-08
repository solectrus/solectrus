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
end
