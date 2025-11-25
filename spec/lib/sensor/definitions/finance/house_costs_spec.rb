describe Sensor::Definitions::HouseCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    subject { sensor.calculate(**params) }

    context 'with both values present' do
      let(:params) { { house_costs_grid: 10.0, house_costs_pv: 5.0 } }

      it { is_expected.to eq(15.0) }
    end

    context 'with house_costs_grid nil' do
      let(:params) { { house_costs_grid: nil, house_costs_pv: 5.0 } }

      it { is_expected.to be_nil }
    end

    context 'with house_costs_pv nil' do
      let(:params) { { house_costs_grid: 10.0, house_costs_pv: nil } }

      it { is_expected.to be_nil }
    end
  end

  describe '#dependencies' do
    subject { sensor.dependencies }

    it { is_expected.to eq(%i[house_costs_grid house_costs_pv]) }
  end
end
