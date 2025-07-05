describe TrendIndicator::Component do
  subject(:component) { described_class.new(trend:) }

  let(:trend) { instance_double(Trend, diff:, more_is_better?: more_is_better) }

  describe '#icon' do
    subject { component.icon }

    context 'when diff is positive' do
      let(:diff) { 1 }
      let(:more_is_better) { true }

      it { is_expected.to eq('fa-arrow-trend-up') }
    end

    context 'when diff is negative' do
      let(:diff) { -1 }
      let(:more_is_better) { true }

      it { is_expected.to eq('fa-arrow-trend-down') }
    end

    context 'when diff is zero' do
      let(:diff) { 0 }
      let(:more_is_better) { true }

      it { is_expected.to be_nil }
    end
  end

  describe '#color_class' do
    subject { component.color_class }

    context 'when positive diff and more is better' do
      let(:diff) { 1 }
      let(:more_is_better) { true }

      it { is_expected.to eq('text-green-600') }
    end

    context 'when negative diff and less is better' do
      let(:diff) { -1 }
      let(:more_is_better) { false }

      it { is_expected.to eq('text-green-600') }
    end

    context 'when positive diff and less is better' do
      let(:diff) { 1 }
      let(:more_is_better) { false }

      it { is_expected.to eq('text-red-700 dark:text-red-400') }
    end

    context 'when negative diff and more is better' do
      let(:diff) { -1 }
      let(:more_is_better) { true }

      it { is_expected.to eq('text-red-700 dark:text-red-400') }
    end
  end
end
