describe Sensor::UnitFormatter do
  describe '.format' do
    it 'scales to the value when auto-scaling' do
      expect(described_class.format(unit: :watt, value: 2_500)).to eq('kW')
    end

    it 'scales to megawatts on request, whatever the value' do
      expect(described_class.format(unit: :watt, value: 5, scaling: :mega)).to eq('MW')
    end

    it 'scales an energy to megawatt-hours on request' do
      expect(described_class.format(unit: :watt, context: :total, scaling: :mega)).to eq('MWh')
    end
  end

  describe '#divisor' do
    it 'is a million for megawatts' do
      expect(described_class.new(unit: :watt, scaling: :mega).divisor).to eq(1_000_000)
    end
  end
end
