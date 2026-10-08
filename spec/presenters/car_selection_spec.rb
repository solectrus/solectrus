describe CarSelection do
  let(:timeframe) { Timeframe.new('2026-01') }

  before do
    Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_2' => 'car2:odometer'))
    Car.create!(id: 1)
    Car.create!(id: 2, active_from: Date.new(2026, 2, 1))
  end

  after { Sensor::Config.setup(ENV) }

  it 'offers the cars in use in the timeframe' do
    expect(described_class.new(nil, timeframe:).offered.map(&:id)).to eq([1])
    expect(described_class.new(nil, timeframe: nil).offered.map(&:id)).to eq([1, 2])
  end

  it 'selects an offered car' do
    selection = described_class.new('1', timeframe:)

    expect(selection.car.id).to eq(1)
    expect(selection.to_param).to eq('1')
  end

  it 'selects "all" without a parameter' do
    selection = described_class.new(nil, timeframe:)

    expect(selection.car).to be_nil
    expect(selection.cars.map(&:id)).to eq([1])
    expect(selection).to be_valid
  end

  it 'is no selection for a car that the timeframe does not offer' do
    [described_class.new('2', timeframe:), described_class.new('x', timeframe:)].each do |selection|
      expect(selection.to_param).to be_nil
      expect(selection).not_to be_valid
    end
  end
end
