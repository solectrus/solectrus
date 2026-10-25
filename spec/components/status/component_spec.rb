describe Status::Component, type: :component do
  subject(:component) { described_class.new(time:, max_age: 10.seconds, status: 'TEST', status_ok:) }

  let(:status_ok) { nil }

  context 'when time is more than 10 seconds ago' do
    let(:time) { 5.minutes.ago }

    it { is_expected.not_to be_live }

    it 'renders the FAIL text' do
      expect(render_inline(component).css('time > .truncate').text).to eq('No data')
    end

    it 'renders the FAIL message in the tooltip' do
      expect(
        render_inline(component).at_css('time [data-tooltip-target=html] .tooltip-detail').text,
      ).to eq "#{I18n.t('data.time')} 5 minutes"
    end
  end

  context 'when time is a few seconds ago and ok is unknown' do
    let(:time) { 3.seconds.ago }

    it { is_expected.to be_live }

    it 'renders the current state in green' do
      rendered = render_inline(component)

      expect(rendered.css('time').text).to eq('TEST')
      expect(rendered.css('time .bg-green-400')).to be_present
    end
  end

  context 'when time is a few seconds ago without status' do
    let(:time) { 3.seconds.ago }

    it 'renders Live' do
      expect(render_inline(described_class.new(time:, max_age: 10.seconds)).css('time').text).to eq('Live')
    end

    it 'renders Online when live is not expected' do
      expect(render_inline(described_class.new(time:, max_age: 10.seconds, live_expected: false)).css('time').text).to eq('Online')
    end

    it 'renders a capsule of glass on the bar and a filled capsule on the page' do
      expect(render_inline(described_class.new(time:, max_age: 10.seconds)).at_css('time.rounded-full.ring-1')).to be_present
      expect(render_inline(described_class.new(time:, max_age: 10.seconds, on_bar: false)).at_css('time.rounded-full.bg-fill')).to be_present
    end
  end

  context 'when live is not expected' do
    subject(:component) { described_class.new(time:, max_age: 48.hours, live_expected: false) }

    context 'when the reading is younger' do
      let(:time) { 47.hours.ago }

      it { is_expected.to be_live }

      it 'renders the label in green' do
        rendered = render_inline(component)

        expect(rendered.css('time > .truncate').text).to eq('Online')
        expect(rendered.css('time .bg-green-400')).to be_present
      end
    end

    context 'when the reading is older' do
      let(:time) { 3.days.ago }

      it { expect(component.state).to eq(:warning) }

      it 'renders the label in yellow, with the age in the tooltip' do
        rendered = render_inline(component)

        expect(rendered.css('time > .truncate').text).to eq('Online')
        expect(rendered.css('time .bg-yellow-400')).to be_present
        expect(rendered.at_css('time [data-tooltip-target=html] .tooltip-detail').text).to eq "#{I18n.t('data.time')} 3 days"
      end
    end

    context 'without a reading' do
      let(:time) { nil }

      it { expect(component.state).to eq(:missing) }

      it 'renders the FAIL text in red' do
        rendered = render_inline(component)

        expect(rendered.css('time > .truncate').text).to eq('No data')
        expect(rendered.css('time .bg-red-400')).to be_present
      end
    end
  end

  context 'when time is a few seconds ago and ok' do
    let(:time) { 3.seconds.ago }
    let(:status_ok) { true }

    it { is_expected.to be_live }

    it 'renders the current state in green' do
      rendered = render_inline(component)

      expect(rendered.css('time').text).to eq('TEST')
      expect(rendered.css('time .bg-green-400')).to be_present
    end
  end

  context 'when time is a few seconds ago and not ok' do
    let(:time) { 3.seconds.ago }
    let(:status_ok) { false }

    it { is_expected.to be_live }

    it 'renders the current state in red' do
      rendered = render_inline(component)

      expect(rendered.css('time').text).to eq('TEST')
      expect(rendered.css('time .bg-yellow-400')).to be_present
    end
  end
end
