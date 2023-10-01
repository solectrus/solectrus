describe Status::Component, type: :component do
  subject(:component) { described_class.new(time:, current_state: 'TEST') }

  context 'when time is more than 10 seconds ago' do
    let(:time) { 5.minutes.ago }

    it { is_expected.not_to be_live }

    it 'renders the FAIL text' do
      expect(render_inline(component).css('time').text).to eq('Disconnected')
    end

    it 'renders the FAIL message' do
      expect(
        render_inline(component).at_css('time')['title'],
      ).to eq "#{I18n.t('calculator.time')} 5 minutes"
    end
  end

  context 'when time is a few seconds ago' do
    let(:time) { 3.seconds.ago }

    it { is_expected.to be_live }

    it 'renders the current state' do
      expect(render_inline(component).css('time').text).to eq('TEST')
    end
  end
end
