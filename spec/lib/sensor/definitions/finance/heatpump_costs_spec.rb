describe Sensor::Definitions::HeatpumpCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  context 'when opportunity_costs is enabled' do
    before { allow(Setting).to receive(:opportunity_costs).and_return(true) }

    describe '#calculate' do
      subject { sensor.calculate(**params) }

      context 'with both values present' do
        let(:params) { { heatpump_costs_grid: 10.0, heatpump_costs_pv: 5.0 } }

        it { is_expected.to eq(15.0) }
      end

      context 'with heatpump_costs_grid nil' do
        let(:params) { { heatpump_costs_grid: nil, heatpump_costs_pv: 5.0 } }

        it { is_expected.to be_nil }
      end

      context 'with heatpump_costs_pv nil' do
        let(:params) { { heatpump_costs_grid: 10.0, heatpump_costs_pv: nil } }

        it { is_expected.to be_nil }
      end
    end

    describe '#dependencies' do
      subject { sensor.dependencies }

      it { is_expected.to eq(%i[heatpump_costs_grid heatpump_costs_pv]) }
    end
  end

  context 'when opportunity_costs is disabled' do
    before { allow(Setting).to receive(:opportunity_costs).and_return(false) }

    describe '#calculate' do
      subject { sensor.calculate(**params) }

      context 'with both values present' do
        let(:params) { { heatpump_costs_grid: 10.0, heatpump_costs_pv: 5.0 } }

        it 'returns only grid costs' do
          is_expected.to eq(10.0)
        end
      end

      context 'with heatpump_costs_grid nil' do
        let(:params) { { heatpump_costs_grid: nil, heatpump_costs_pv: 5.0 } }

        it { is_expected.to be_nil }
      end

      context 'with only heatpump_costs_grid present' do
        let(:params) { { heatpump_costs_grid: 10.0 } }

        it 'returns grid costs' do
          is_expected.to eq(10.0)
        end
      end
    end

    describe '#dependencies' do
      subject { sensor.dependencies }

      it { is_expected.to eq([:heatpump_costs_grid]) }
    end
  end
end
