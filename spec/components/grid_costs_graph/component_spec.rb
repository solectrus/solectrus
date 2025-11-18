describe GridCostsGraph::Component do
  subject(:component) { described_class.new(costs:, revenue:) }

  let(:costs) { 100 }
  let(:revenue) { 150 }

  describe '#costs_width' do
    subject { component.costs_width }

    it { is_expected.to eq(67) }

    context 'when max is zero' do
      let(:costs) { 0 }
      let(:revenue) { 0 }

      it { is_expected.to eq(0) }
    end
  end

  describe '#revenue_width' do
    subject { component.revenue_width }

    it { is_expected.to eq(100) }

    context 'when max is zero' do
      let(:costs) { 0 }
      let(:revenue) { 0 }

      it { is_expected.to eq(0) }
    end
  end

  describe '#profit' do
    subject { component.profit }

    it { is_expected.to eq(50) }

    context 'when costs exceed revenue' do
      let(:costs) { 200 }
      let(:revenue) { 100 }

      it { is_expected.to eq(-100) }
    end
  end
end
