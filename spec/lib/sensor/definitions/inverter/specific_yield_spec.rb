describe Sensor::Definitions::SpecificYield do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    subject(:calculate) { sensor.calculate(inverter_power:) }

    let(:update_check) { instance_double(UpdateCheck) }

    before do
      allow(UpdateCheck).to receive(:instance).and_return(update_check)
      allow(update_check).to receive(:kwp).and_return(kwp)
    end

    context 'when inverter_power and kwp are both present' do
      let(:inverter_power) { 10_000 }
      let(:kwp) { 8 }

      it { is_expected.to eq(1250) }
    end

    context 'when kwp is zero' do
      let(:inverter_power) { 10_000 }
      let(:kwp) { 0 }

      it { is_expected.to be_nil }
    end

    context 'when kwp is nil' do
      let(:inverter_power) { 10_000 }
      let(:kwp) { nil }

      it { is_expected.to be_nil }
    end

    context 'when inverter_power is nil' do
      let(:inverter_power) { nil }
      let(:kwp) { 8.5 }

      it { is_expected.to be_nil }
    end

    context 'when inverter_power is zero' do
      let(:inverter_power) { 0 }
      let(:kwp) { 8.5 }

      it { is_expected.to eq(0) }
    end
  end
end
