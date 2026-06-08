Sensor::Registry[:total_consumption]

describe Sensor::Definitions::TotalConsumption do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    context 'when a custom consumer is excluded from house_power' do
      let(:env) do
        {
          'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
          'INFLUX_SENSOR_HEATPUMP_POWER' => 'pv:heatpump_power',
          'INFLUX_SENSOR_CUSTOM_POWER_01' => 'custom:power_01',
          'INFLUX_SENSOR_CUSTOM_POWER_02' => 'custom:power_02',
          'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'CUSTOM_POWER_02',
        }
      end

      before { Sensor::Config.setup(env) }

      after { Sensor::Config.setup(ENV) }

      # house_power is reduced by the excluded custom consumer in both the live
      # (InfluxDB) value and the stored summary value, so it must be added back.
      it 'adds the excluded custom consumer back to the total' do
        result =
          sensor.calculate(
            house_power: 800, # already reduced by custom_power_02
            heatpump_power: 300,
            custom_power_02: 200,
          )

        expect(result).to eq(800 + 300 + 200)
      end

      it 'depends on the excluded custom consumer' do
        expect(sensor.dependencies).to include(:custom_power_02)
      end
    end

    context 'when no custom consumer is excluded' do
      let(:env) do
        {
          'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
          'INFLUX_SENSOR_HEATPUMP_POWER' => 'pv:heatpump_power',
        }
      end

      before { Sensor::Config.setup(env) }

      after { Sensor::Config.setup(ENV) }

      it 'sums house_power and heatpump_power' do
        result = sensor.calculate(house_power: 800, heatpump_power: 300)

        expect(result).to eq(1100)
      end

      it 'stays nil when no consumer has data' do
        result = sensor.calculate(house_power: nil)

        expect(result).to be_nil
      end
    end
  end
end
