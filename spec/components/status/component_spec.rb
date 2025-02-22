describe Status::Component, type: :component do
  subject(:component) { described_class.new(time:, status: 'TEST', status_ok:) }

  let(:status_ok) { nil }

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

  context 'when time is a few seconds ago and ok is unknown' do
    let(:time) { 3.seconds.ago }

    it { is_expected.to be_live }

    it 'renders the current state in green' do
      expect(render_inline(component).css('time').text).to eq('TEST')
      expect(render_inline(component).css('time .bg-green-500')).to be_present
    end
  end

  context 'when time is a few seconds ago and ok' do
    let(:time) { 3.seconds.ago }
    let(:status_ok) { true }

    it { is_expected.to be_live }

    it 'renders the current state in green' do
      expect(render_inline(component).css('time').text).to eq('TEST')
      expect(render_inline(component).css('time .bg-green-500')).to be_present
    end
  end

  context 'when time is a few seconds ago and not ok' do
    let(:time) { 3.seconds.ago }
    let(:status_ok) { false }

    it { is_expected.to be_live }

    it 'renders the current state in orange' do
      expect(render_inline(component).css('time').text).to eq('TEST')
      expect(render_inline(component).css('time .bg-orange-400')).to be_present
    end
  end
end
