Sensor::Registry[:custom_power_total]

describe Sensor::Definitions::CustomPowerTotal do # rubocop:disable RSpec/SpecFilePathFormat
  describe '#calculate' do
    context 'when some custom sensors are excluded from house power' do
      let(:env) do
        {
          'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
          'INFLUX_SENSOR_CUSTOM_POWER_01' => 'custom:power_01',
          'INFLUX_SENSOR_CUSTOM_POWER_02' => 'custom:power_02',
          'INFLUX_SENSOR_CUSTOM_POWER_03' => 'custom:power_03',
          'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'CUSTOM_POWER_03',
        }
      end

      before { Sensor::Config.setup(env) }

      it 'only sums included custom sensors' do
        sensor = described_class.new
        result =
          sensor.calculate(
            custom_power_01: 100,
            custom_power_02: 200,
            custom_power_03: 300, # This should be excluded
          )

        # Only custom_power_01 and custom_power_02 should be summed
        expect(result).to eq(300)
      end
    end

    context 'when no custom sensors are excluded' do
      let(:env) do
        {
          'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
          'INFLUX_SENSOR_CUSTOM_POWER_01' => 'custom:power_01',
          'INFLUX_SENSOR_CUSTOM_POWER_02' => 'custom:power_02',
        }
      end

      before { Sensor::Config.setup(env) }

      it 'sums all custom sensors' do
        sensor = described_class.new
        result = sensor.calculate(custom_power_01: 100, custom_power_02: 200)

        expect(result).to eq(300)
      end
    end
  end
end
