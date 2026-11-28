describe Sensor::Definitions::CustomPower do # rubocop:disable RSpec/SpecFilePathFormat
  describe '#color_background' do
    def setup_config(excluded)
      # A sensor caches its colors, so a new configuration needs new sensors
      Sensor::Registry.reset!
      Sensor::Config.setup(
        {
          'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
          'INFLUX_SENSOR_CUSTOM_POWER_01' => 'custom:power_01',
          'INFLUX_SENSOR_CUSTOM_POWER_02' => 'custom:power_02',
          'INFLUX_SENSOR_CUSTOM_POWER_03' => 'custom:power_03',
          'INFLUX_SENSOR_CUSTOM_POWER_04' => 'custom:power_04',
          'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => excluded,
        },
      )
    end

    after do
      Sensor::Registry.reset!
      Sensor::Config.setup(ENV)
    end

    def color_of(name) = Sensor::Registry[name].color_background

    context 'with two excluded consumers' do
      before { setup_config('CUSTOM_POWER_02,CUSTOM_POWER_04') }

      it 'counts the positions among the included consumers' do
        expect(color_of(:custom_power_01)).to eq('bg-sensor-consumer-01')
        expect(color_of(:custom_power_03)).to eq('bg-sensor-consumer-03')
      end

      it 'spreads the excluded consumers over the house shades' do
        expect(color_of(:custom_power_02)).to eq('bg-sensor-house-shade-2')
        expect(color_of(:custom_power_04)).to eq('bg-sensor-house-shade-4')
      end
    end

    context 'with one excluded consumer' do
      before { setup_config('CUSTOM_POWER_02') }

      it 'takes the middle house shade' do
        expect(color_of(:custom_power_02)).to eq('bg-sensor-house-shade-3')
      end
    end
  end
end
