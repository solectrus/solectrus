describe Insights::TrendIndicator::Component, type: :component do
  subject(:component) { described_class.new(trend:) }

  let(:trend) do
    instance_double(Trend, diff:, more_is_better?: more_is_better, sensor:)
  end
  let(:sensor) { double('Sensor', trend_aggregation: trend_aggregation, unit: :watt) }
  let(:trend_aggregation) { :sum }

  describe '#icon_name' do
    subject { component.icon_name }

    context 'when diff is positive' do
      let(:diff) { 1 }
      let(:more_is_better) { true }

      it { is_expected.to eq('arrow-trend-up') }
    end

    context 'when diff is negative' do
      let(:diff) { -1 }
      let(:more_is_better) { true }

      it { is_expected.to eq('arrow-trend-down') }
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

  describe '#percent?' do
    subject { component.percent? }

    let(:diff) { 1 }
    let(:more_is_better) { true }

    context 'when sensor unit is watt' do
      it { is_expected.to be false }
    end

    context 'when sensor unit is percent' do
      let(:sensor) { double('Sensor', trend_aggregation: :avg, unit: :percent) }

      it { is_expected.to be true }
    end
  end

  describe '#show_diff_value?' do
    subject(:show_diff_value) { component.show_diff_value? }

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

    context 'when sensor unit is percent' do
      let(:sensor) { double('Sensor', trend_aggregation: :sum, unit: :percent) }

      it { is_expected.to be true }
    end
  end

  # The unit behind the change
  describe 'rendered change' do
    subject(:text) { render_inline(component).text.squish }

    let(:trend) do
      instance_double(Trend, diff:, more_is_better?: true, sensor:, same?: diff.zero?, precision: 0, percent: 25)
    end

    context 'with a percentage sensor' do
      let(:sensor) { double('Sensor', trend_aggregation: :avg, unit: :percent) }
      let(:diff) { 3 }

      it 'shows the change in percentage points' do
        expect(text).to eq('+3 pp')
      end
    end

    context 'with an average' do
      let(:sensor) { double('Sensor', trend_aggregation: :avg, unit: :celsius) }
      let(:diff) { 2 }

      it 'shows the change without a unit' do
        expect(text).to eq('+2')
      end
    end

    context 'with a sum that did not change' do
      let(:diff) { 0 }

      it 'shows no change in percent' do
        expect(text).to eq('± 0%')
      end
    end
  end
end
