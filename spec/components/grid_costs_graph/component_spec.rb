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

  describe '#amounts' do
    subject(:amounts) { component.amounts }

    it { expect(amounts.sum).to eq(50) }

    context 'when costs exceed revenue' do
      let(:costs) { 200 }
      let(:revenue) { 100 }

      it { expect(amounts.sum).to eq(-100) }
    end

    # Rounded on their own, 234 - 124 = 111
    context 'with amounts that round away from the balance' do
      let(:costs) { 123.6 }
      let(:revenue) { 234.3 }

      it 'rounds them to add up' do
        expect(amounts.sum).to eq(111)
        expect(amounts.parts.sum).to eq(111)
      end
    end

    # The tooltips of the finance badges show 1,25 and 0,99
    context 'with costs that keep their value' do
      let(:costs) { 1.2474 }
      let(:revenue) { 0.9827 }

      it 'lets the revenue take the rest' do
        expect(amounts.parts).to eq([-1.25, 0.99])
        expect(amounts.sum).to eq(-0.26)
      end
    end
  end
end
