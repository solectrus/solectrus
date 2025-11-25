describe Sensor::Definitions::CustomCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new(1) }

  context 'when opportunity_costs is enabled' do
    before { allow(Setting).to receive(:opportunity_costs).and_return(true) }

    describe '#calculate' do
      subject { sensor.calculate(**params) }

      context 'with both values present' do
        let(:params) { { custom_costs_01_grid: 10.0, custom_costs_01_pv: 5.0 } }

        it { is_expected.to eq(15.0) }
      end

      context 'with custom_costs_01_grid nil' do
        let(:params) { { custom_costs_01_grid: nil, custom_costs_01_pv: 5.0 } }

        it { is_expected.to be_nil }
      end

      context 'with custom_costs_01_pv nil' do
        let(:params) { { custom_costs_01_grid: 10.0, custom_costs_01_pv: nil } }

        it { is_expected.to be_nil }
      end
    end

    describe '#dependencies' do
      subject { sensor.dependencies }

      it { is_expected.to eq(%i[custom_costs_01_grid custom_costs_01_pv]) }
    end
  end

  context 'when opportunity_costs is disabled' do
    before { allow(Setting).to receive(:opportunity_costs).and_return(false) }

    describe '#calculate' do
      subject { sensor.calculate(**params) }

      context 'with both values present' do
        let(:params) { { custom_costs_01_grid: 10.0, custom_costs_01_pv: 5.0 } }

        it 'returns only grid costs' do
          is_expected.to eq(10.0)
        end
      end

      context 'with custom_costs_01_grid nil' do
        let(:params) { { custom_costs_01_grid: nil, custom_costs_01_pv: 5.0 } }

        it { is_expected.to be_nil }
      end

      context 'with only custom_costs_01_grid present' do
        let(:params) { { custom_costs_01_grid: 10.0 } }

        it 'returns grid costs' do
          is_expected.to eq(10.0)
        end
      end
    end

    describe '#dependencies' do
      subject { sensor.dependencies }

      it { is_expected.to eq([:custom_costs_01_grid]) }
    end
  end
end
