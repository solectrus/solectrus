describe InverterBalance do
  subject(:inverter_balance) { described_class.new(sensor_data) }

  let(:sensor_data) { Sensor::Data::Single.new(raw_data, timeframe:) }
  let(:raw_data) do
    {
      inverter_power: 900,
      inverter_power_1: 800,
      inverter_power_2: 98,
      inverter_power_total: 898,
      inverter_power_difference: 2,
    }
  end
  let(:timeframe) { Timeframe.now }

  describe '#inverter_power_1_percent' do
    subject(:inverter_power_1_percent) do
      inverter_balance.inverter_power_1_percent
    end

    it 'calculates as percentage of inverter_total' do
      expect(inverter_power_1_percent).to eq(88.9)
    end
  end

  describe '#inverter_power_2_percent' do
    subject(:inverter_power_2_percent) do
      inverter_balance.inverter_power_2_percent
    end

    it 'calculates as percentage of inverter_total' do
      expect(inverter_power_2_percent).to eq(10.9)
    end
  end

  describe '#inverter_power_difference' do
    subject(:inverter_power_difference) do
      inverter_balance.inverter_power_difference
    end

    it 'calculates the difference' do
      expect(inverter_power_difference).to eq(2)
    end
  end

  describe 'method delegation' do
    it 'delegates calls to the wrapped sensor_data' do
      expect(inverter_balance.timeframe).to eq(timeframe)
      expect(inverter_balance.valid_multi_inverter?).to be true
      expect(inverter_balance.inverter_power).to eq(900)
    end

    it 'responds to methods on the wrapped object' do
      expect(inverter_balance).to respond_to(:timeframe)
      expect(inverter_balance).to respond_to(:valid_multi_inverter?)
      expect(inverter_balance).to respond_to(:inverter_power)
    end

    it 'does not respond to invalid methods' do
      expect(inverter_balance).not_to respond_to(:invalid_method)
    end
  end
end
