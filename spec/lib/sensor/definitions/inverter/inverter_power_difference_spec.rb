describe Sensor::Definitions::InverterPowerDifference do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    subject(:calculate) do
      sensor.calculate(inverter_power:, inverter_power_total:)
    end

    context 'when difference is significant (> 1% of total)' do
      let(:inverter_power) { 5000 }
      let(:inverter_power_total) { 4500 }

      it 'returns the difference' do
        expect(calculate).to eq(500)
      end
    end

    context 'when difference is small (< 1% of total)' do
      let(:inverter_power) { 5000 }
      let(:inverter_power_total) { 4950 }

      it 'suppresses small differences and returns nil' do
        expect(calculate).to be_nil
      end
    end

    context 'when inverter_power is nil' do
      let(:inverter_power) { nil }
      let(:inverter_power_total) { 4500 }

      it 'returns nil' do
        expect(calculate).to be_nil
      end
    end

    context 'when inverter_power_total is nil' do
      let(:inverter_power) { 1000 }
      let(:inverter_power_total) { nil }

      it 'treats total as 0 and returns full inverter_power as difference' do
        expect(calculate).to eq(1000)
      end
    end
  end
end
