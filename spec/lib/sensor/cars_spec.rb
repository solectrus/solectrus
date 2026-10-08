describe Sensor::Cars do
  it 'makes a sensor of each role for each number' do
    expect(Sensor::Registry.find(:car_odometer_5)).to be_present
    expect(Sensor::Registry.find(:car_odometer_6)).to be_nil
  end

  it 'reads the number of a car sensor' do
    expect(described_class.number_of(:car_max_range_3)).to eq(3)
    expect(described_class.number_of(:wallbox_power)).to be_nil
  end

  it 'puts the state of charge of a car in the category of the car' do
    expect(Sensor::Registry[:car_battery_soc_1].category).to eq(:car)
  end

  describe '.configured_numbers' do
    after { Sensor::Config.setup(ENV) }

    it 'takes a number with one variable' do
      Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_RANGE_2' => 'car2:range'))

      expect(described_class.configured_numbers).to eq([1, 2])
    end
  end

  describe 'the name of a car sensor' do
    it 'is the name of the car plus the role' do
      Car.create!(id: 1, name: 'Model Y')

      expect(Sensor::Registry[:car_battery_soc_1].display_name).to eq('Model Y (SOC)')
      expect(Sensor::Registry[:car_battery_soc_1]).to be_user_defined_name
    end

    it 'comes from I18n for a car without a name' do
      expect(Sensor::Registry[:car_odometer_2].display_name).to eq('Car 2: Odometer')
      expect(Sensor::Registry[:car_odometer_2]).not_to be_user_defined_name
    end

    it 'is in German for a German installation' do
      I18n.with_locale(:de) do
        expect(Sensor::Registry[:car_odometer_2].display_name).to eq('Auto 2: Kilometerstand')
      end
    end
  end

  describe 'the maximum range of a car' do
    after { Sensor::Config.setup(ENV) }

    it 'exists only with the range and the state of charge of its car' do
      Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_RANGE_1' => 'car:range'))

      expect(Sensor::Config.exists?(:car_max_range_1, check_policy: false)).to be(true)
      expect(Sensor::Config.exists?(:car_max_range_2, check_policy: false)).to be(false)
    end
  end
end
