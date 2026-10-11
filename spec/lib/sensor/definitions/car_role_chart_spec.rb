describe Sensor::Definitions::CarRoleChart do
  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_BATTERY_SOC_1' => 'Trabant:soc',
        'INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc',
      ),
    )
    Car.create!(id: 1, name: 'Model Y')
  end

  after { Sensor::Config.setup(ENV) }

  it 'names the sensor of each car with the name of its car' do
    expect(Sensor::Registry[:car_battery_soc].data_sensors).to eq(
      car_battery_soc_1: 'Model Y',
      car_battery_soc_2: Car.display_name_of(2),
    )
  end

  it 'gives no data sensors to another sensor' do
    expect(Sensor::Registry[:house_power].data_sensors).to be_nil
  end
end
