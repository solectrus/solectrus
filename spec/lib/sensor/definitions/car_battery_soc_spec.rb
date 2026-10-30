describe Sensor::Definitions::CarBatterySoc do
  subject(:sensor) { Sensor::Registry[:car_battery_soc_1] }

  describe '#display_name' do
    it 'is named like the home battery' do
      Car.create!(id: 1, name: 'Model Y')

      I18n.with_locale(:de) do
        expect(sensor.display_name).to eq('Ladestand Model Y')
        expect(Sensor::Registry[:battery_soc].display_name).to eq('Ladestand Hausakku')
      end
    end

    it 'prefers the short name of the car' do
      Car.create!(id: 1, name: 'Renault Zoe', short_name: 'ZOE')

      expect(sensor.display_name).to eq('ZOE SOC')
    end

    it 'calls the one car in use without a name just the car' do
      expect(sensor.display_name).to eq('EV SOC')
    end

    it 'hides the name of the car from a visitor' do
      Car.create!(id: 1, name: 'Renault Zoe', short_name: 'ZOE')
      Current.car_names_hidden = true

      expect(sensor.display_name).to eq('EV SOC')
    end

    context 'with a second car in use' do
      before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc')) }

      after { Sensor::Config.setup(ENV) }

      it 'names a car without a name by its number' do
        expect(sensor.display_name).to eq('Car 1 SOC')
      end
    end
  end

  describe '#home_pages' do
    it 'puts the one car in use on the power balance' do
      expect(sensor.home_pages).to eq([:balance])
    end

    context 'with a second car in use' do
      before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc')) }

      after { Sensor::Config.setup(ENV) }

      it 'leaves the chart to the car page' do
        expect(sensor.home_pages).to be_empty
      end
    end
  end

  describe '#chart' do
    it 'draws the state of charge of its car' do
      chart = sensor.chart(Timeframe.day)

      expect(chart.car.id).to eq(1)
      expect(chart).to be_supported
    end
  end
end
