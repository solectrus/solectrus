describe Sensor::Units do
  describe '.[]' do
    it 'returns the definition for a unit' do
      expect(described_class[:watt]).to be_a(Sensor::Units::Watt)
    end

    it 'falls back to the null definition for an unknown unit' do
      expect(described_class[:parsec]).to be_a(Sensor::Units::Null)
    end

    it 'returns the null definition for no unit at all' do
      expect(described_class[nil]).to be_a(Sensor::Units::Null)
    end
  end

  describe '.names' do
    it 'lists the units a sensor may declare' do
      expect(described_class.names).to include(:watt, :money, :percent)
    end

    it 'does not list the internal null unit' do
      expect(described_class.names).not_to include(nil)
    end
  end

  describe 'scaling' do
    it 'scales watt up to megawatts' do
      expect(described_class[:watt].scale_steps.last).to include(
        divisor: 1_000_000,
        prefix: 'M',
      )
    end

    it 'leaves units without scale steps alone' do
      expect(described_class[:percent]).not_to be_scalable
    end
  end

  describe 'labels' do
    it 'tells an amount from a rate' do
      watt = described_class[:watt]

      expect(watt.label(prefix: 'k', context: :total)).to eq('kWh')
      expect(watt.label(prefix: 'k', context: :rate)).to eq('kW')
    end

    it 'names a thousand kilograms a tonne, not a "tg"' do
      expect(described_class[:gram].label(prefix: 't', context: :total)).to eq(
        't',
      )
    end
  end
end
