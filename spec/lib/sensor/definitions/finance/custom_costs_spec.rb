describe Sensor::Definitions::CustomCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new(1) }

  describe '#calculate' do
    subject { sensor.calculate(**params) }

    context 'with both values present' do
      let(:params) { { custom_01_costs_grid: 10.0, custom_01_costs_pv: 5.0 } }

      it { is_expected.to eq(15.0) }
    end

    context 'with custom_01_costs_grid nil' do
      let(:params) { { custom_01_costs_grid: nil, custom_01_costs_pv: 5.0 } }

      it { is_expected.to be_nil }
    end

    context 'with custom_01_costs_pv nil' do
      let(:params) { { custom_01_costs_grid: 10.0, custom_01_costs_pv: nil } }

      it { is_expected.to be_nil }
    end
  end

  describe '#dependencies' do
    subject { sensor.dependencies }

    it { is_expected.to eq(%i[custom_01_costs_grid custom_01_costs_pv]) }
  end
end
