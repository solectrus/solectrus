describe Flow::Component, type: :component do
  let(:component) { described_class.new(value: value, signal: true) }

  describe '#height' do
    subject { component.height }

    context 'when 150%' do
      let(:value) { 15_000 }

      it { is_expected.to eq('100%') }
    end

    context 'when 100%' do
      let(:value) { 10_000 }

      it { is_expected.to eq('100%') }
    end

    context 'when 3/4' do
      let(:value) { 7_500 }

      it { is_expected.to eq('98%') }
    end

    context 'when 1/2' do
      let(:value) { 5_000 }

      it { is_expected.to eq('88%') }
    end

    context 'when 1/3' do
      let(:value) { 3_333 }

      it { is_expected.to eq('70%') }
    end

    context 'when 5%' do
      let(:value) { 500 }

      it { is_expected.to eq('14%') }
    end

    context 'when 0' do
      let(:value) { 0 }

      it { is_expected.to eq('0%') }
    end
  end
end
