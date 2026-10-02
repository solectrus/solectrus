describe Car::UnratedNote::Component, type: :component do
  subject(:component) { described_class.new(distance:, rated_distance: 64_790.2) }

  context 'with days without a rate' do
    let(:distance) { 64_800.4 }

    it 'names their kilometers' do
      expect(render_inline(component).text).to include('Without 10 km that lack charging data')
    end
  end

  context 'with a rest that rounds to 0' do
    let(:distance) { 64_790.6 }

    it { expect(component).not_to be_render }
  end
end
