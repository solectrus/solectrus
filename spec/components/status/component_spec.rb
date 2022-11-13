describe Status::Component, type: :component do
  subject(:component) { described_class.new(time:) }

  context 'when time is more than 10 seconds ago' do
    let(:time) { 30.seconds.ago }

    it { is_expected.not_to be_live }

    it 'renders the FAIL text' do
      expect(render_inline(component).css('div').text).to eq('FAIL')
    end
  end

  context 'when time is a few seconds ago' do
    let(:time) { 3.seconds.ago }

    it { is_expected.to be_live }

    it 'renders the LIVE text' do
      expect(render_inline(component).css('div').text).to eq('LIVE')
    end
  end
end
