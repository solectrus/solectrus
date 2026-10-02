describe Car::Provisioning do
  before do
    Sensor::Config.setup(
      ENV.to_h.merge('INFLUX_SENSOR_CAR_MILEAGE_3' => 'car3:odometer'),
    )
  end

  after { Sensor::Config.setup(ENV) }

  # The test configuration has the state of charge of the first car
  it 'creates a car for each configured number without a car' do
    expect(described_class.call.map(&:id)).to eq([1, 3])
  end

  it 'starts a new car at the installation date' do
    expect(described_class.call.map(&:active_from).uniq).to eq([Rails.configuration.x.installation_date])
  end

  it 'keeps an existing car' do
    Car.create!(id: 3, name: 'Wartburg')

    expect { described_class.call }.to change(Car, :count).from(1).to(2)
    expect(Car.find(3).name).to eq('Wartburg')
  end

  it 'gives no car to a number without a configuration' do
    Car.create!(id: 2)

    expect(described_class.call.map(&:id)).to eq([1, 3])
  end
end
