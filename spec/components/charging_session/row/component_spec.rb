describe ChargingSession::Row::Component, type: :component do
  subject(:html) { render_inline(described_class.new(charging_session:)) }

  let(:car) { Car.new(id: 1, battery_kwh: 50) }
  let(:started_at) { Time.zone.local(2026, 6, 15, 12) }

  def session(**) = ChargingSession.new(kind: :wallbox, car:, started_at:, ended_at: started_at + 2.hours, kwh: 20, **)

  # The dots that pulse while the session charges
  def dots = html.css(%([role="img"][aria-label="#{I18n.t('charging_sessions.ongoing')}"]))

  before { allow(vc_test_controller).to receive(:admin?).and_return(false) }

  context 'with an ongoing session' do
    let(:charging_session) { session(ongoing: true) }

    it 'marks it with a pulsing dot, on the desktop and on a phone' do
      expect(dots.size).to eq(2)
      expect(dots.css('.animate-ping').size).to eq(2)
    end
  end

  context 'with a finished session' do
    let(:charging_session) { session(soc_from: 30, soc_to: 70) }

    it 'has no dot' do
      expect(dots).to be_empty
    end
  end

  # 75 -> 75 % with 20 kWh
  context 'with a state of charge that contradicts the energy' do
    let(:charging_session) { session(soc_from: 75, soc_to: 75) }

    it 'explains it in a tooltip' do
      hint = html.at_css('[data-tooltip-target="html"]').text.squish

      expect(hint).to include(I18n.t('charging_sessions.soc_finding.mismatch.text').upcase_first)
      expect(hint).to include(I18n.t('charging_sessions.soc_finding.mismatch.hint'))
    end
  end
end
