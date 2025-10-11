describe Balance::Component do
  subject(:component) { described_class.new(data:, timeframe:, sensor:) }

  let(:data) { instance_double(Sensor::Data::Single) }
  let(:timeframe) { instance_double(Timeframe) }
  let(:sensor) { :inverter_power }

  it 'initializes with data, timeframe and sensor' do
    expect(component.data).to eq(data)
    expect(component.timeframe).to eq(timeframe)
    expect(component.sensor).to eq(sensor)
  end
end
