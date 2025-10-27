describe Sensor::Query::Helpers::Influx::Base do
  let(:sensor_names) { %i[inverter_power house_power] }
  let(:timeframe) { Timeframe.now }

  describe '#initialize' do
    it 'inherits from Base class' do
      expect(described_class.superclass).to eq(Sensor::Query::Base)
    end
  end
end
