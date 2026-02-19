describe TrendIndicator::Component do
  subject(:component) { described_class.new(trend:) }

  let(:trend) do
    instance_double(Trend, diff:, more_is_better?: more_is_better, sensor:)
  end
  let(:sensor) { double('Sensor', trend_aggregation: trend_aggregation) }
  let(:trend_aggregation) { :sum }

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

      it { is_expected.to eq('text-signal-positive') }
    end

    context 'when negative diff and less is better' do
      let(:diff) { -1 }
      let(:more_is_better) { false }

      it { is_expected.to eq('text-signal-positive') }
    end

    context 'when positive diff and less is better' do
      let(:diff) { 1 }
      let(:more_is_better) { false }

      it { is_expected.to eq('text-signal-negative') }
    end

    context 'when negative diff and more is better' do
      let(:diff) { -1 }
      let(:more_is_better) { true }

      it { is_expected.to eq('text-signal-negative') }
    end
  end

  describe '#diff_precision' do
    subject { component.diff_precision }

    let(:diff) { 1 }
    let(:more_is_better) { true }

    context 'when sensor uses sum aggregation' do
      let(:trend_aggregation) { :sum }

      it { is_expected.to eq(0) }
    end

    context 'when sensor uses avg aggregation' do
      let(:trend_aggregation) { :avg }

      it { is_expected.to eq(1) }
    end
  end

  describe '#show_absolute_values?' do
    subject { component.show_absolute_values? }

    let(:diff) { 1 }
    let(:more_is_better) { true }

    context 'when sensor uses sum aggregation' do
      let(:trend_aggregation) { :sum }

      it { is_expected.to be false }
    end

    context 'when sensor uses avg aggregation' do
      let(:trend_aggregation) { :avg }

      it { is_expected.to be true }
    end
  end
end
