describe Sensor::Definitions::TotalCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    subject { sensor.calculate(**params) }

    context 'with both values present' do
      let(:params) { { grid_costs: 10.0, opportunity_costs: 5.0 } }

      it { is_expected.to eq(15.0) }
    end

    context 'with grid_costs nil' do
      let(:params) { { grid_costs: nil, opportunity_costs: 5.0 } }

      it { is_expected.to be_nil }
    end

    context 'with opportunity_costs nil' do
      let(:params) { { grid_costs: 10.0, opportunity_costs: nil } }

      it { is_expected.to be_nil }
    end
  end

  describe '#top10_enabled?' do
    subject { sensor.top10_enabled? }

    it { is_expected.to be(true) }
  end

  describe '#top10_permitted?' do
    subject { sensor.top10_permitted? }

    context 'when finance_top10 is enabled' do
      before { allow(ApplicationPolicy).to receive(:finance_top10?).and_return(true) }

      it { is_expected.to be(true) }
    end

    context 'when finance_top10 is disabled' do
      before { allow(ApplicationPolicy).to receive(:finance_top10?).and_return(false) }

      it { is_expected.to be(false) }
    end
  end

  describe '#dependencies' do
    subject { sensor.dependencies }

    it { is_expected.to eq(%i[grid_costs opportunity_costs]) }
  end

  describe '#chart_enabled?' do
    subject { sensor.chart_enabled? }

    it { is_expected.to be(true) }
  end

  describe '#summary_meta_aggregations' do
    subject { sensor.summary_meta_aggregations }

    it { is_expected.to eq(%i[sum min max]) }
  end
end
