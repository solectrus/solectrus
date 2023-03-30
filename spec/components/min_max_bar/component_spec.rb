describe MinMaxBar::Component, type: :component do
  let(:component) { described_class.new(title:, minmax:, color:, range:) }

  let(:title) { 'Temperature' }
  let(:color) { :blue }
  let(:range) { 0..100 }
  let(:minmax) { [10, 20] }

  describe 'rendering' do
    subject { page }

    before { render_inline(component) }

    context 'when blue' do
      let(:color) { :blue }

      it { is_expected.to have_css('.bg-sky-400') }
    end

    context 'when red' do
      let(:color) { :red }

      it { is_expected.to have_css('.bg-red-400') }
    end
  end

  describe '#extent' do
    subject { component.extent }

    context 'when range is 0..100' do
      let(:range) { 0..100 }

      it { is_expected.to eq(100) }
    end

    context 'when range is 5..40' do
      let(:range) { 5..40 }

      it { is_expected.to eq(35) }
    end
  end

  describe '#width_in_percent' do
    subject { component.width_in_percent }

    context 'when minmax is [10, 30]' do
      let(:minmax) { [10, 30] }

      it { is_expected.to eq(20) }
    end

    context 'when minmax is [100, 100]' do
      let(:minmax) { [100, 100] }

      it { is_expected.to eq(0) }
    end
  end
end
