describe Sensor::Definitions::WallboxCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  context 'when opportunity_costs is enabled' do
    before { allow(Setting).to receive(:opportunity_costs).and_return(true) }

    describe '#calculate' do
      subject { sensor.calculate(**params) }

      context 'with both values present' do
        let(:params) { { wallbox_costs_grid: 10.0, wallbox_costs_pv: 5.0 } }

        it { is_expected.to eq(15.0) }
      end

      context 'with wallbox_costs_grid nil' do
        let(:params) { { wallbox_costs_grid: nil, wallbox_costs_pv: 5.0 } }

        it { is_expected.to be_nil }
      end

      context 'with wallbox_costs_pv nil' do
        let(:params) { { wallbox_costs_grid: 10.0, wallbox_costs_pv: nil } }

        it { is_expected.to be_nil }
      end
    end

    describe '#dependencies' do
      subject { sensor.dependencies }

      it { is_expected.to eq(%i[wallbox_costs_grid wallbox_costs_pv]) }
    end
  end

  context 'when opportunity_costs is disabled' do
    before { allow(Setting).to receive(:opportunity_costs).and_return(false) }

    describe '#calculate' do
      subject { sensor.calculate(**params) }

      context 'with both values present' do
        let(:params) { { wallbox_costs_grid: 10.0, wallbox_costs_pv: 5.0 } }

        it 'returns only grid costs' do
          is_expected.to eq(10.0)
        end
      end

      context 'with wallbox_costs_grid nil' do
        let(:params) { { wallbox_costs_grid: nil, wallbox_costs_pv: 5.0 } }

        it { is_expected.to be_nil }
      end

      context 'with only wallbox_costs_grid present' do
        let(:params) { { wallbox_costs_grid: 10.0 } }

        it 'returns grid costs' do
          is_expected.to eq(10.0)
        end
      end
    end

    describe '#dependencies' do
      subject { sensor.dependencies }

      it { is_expected.to eq([:wallbox_costs_grid]) }
    end
  end
end
