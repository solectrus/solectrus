describe ChargingSession::SocFacts::Component, type: :component do
  let(:car) { Car.new(id: 1, battery_kwh: 50) }

  def session(**) = ChargingSession.new(kind: :wallbox, car:, **)

  it 'names the state of charge' do
    render_inline(described_class.new(charging_session: ChargingSession.new(kind: :wallbox, soc_from: 64, soc_to: 65), css_class: 'mt-3'))

    expect(page).to have_css('p.mt-3', text: I18n.t('charging_sessions.soc', range: '64 → 65%'))
  end

  it 'renders nothing without a state of charge' do
    render_inline(described_class.new(charging_session: ChargingSession.new(kind: :wallbox)))

    expect(page).to have_no_css('p')
  end

  # 40 % of 50 kWh = 20 kWh of 22 kWh
  it 'names the loss' do
    render_inline(described_class.new(charging_session: session(soc_from: 30, soc_to: 70, kwh: 22)))

    expect(page).to have_css('p', text: I18n.t('charging_sessions.loss', percent: '9%'))
  end

  # 40 % of 50 kWh = 20 kWh of 18 kWh
  it 'explains a rise above the energy in place of a negative loss' do
    render_inline(described_class.new(charging_session: session(soc_from: 30, soc_to: 70, kwh: 18)))

    expect(page).to have_css('p', text: I18n.t('charging_sessions.soc_finding.above_energy.text'))
    expect(page).to have_css('p span.block', text: I18n.t('charging_sessions.soc_finding.above_energy.hint'))
    expect(page).to have_no_text('-11')
  end

  it 'explains a state of charge that contradicts the energy' do
    render_inline(described_class.new(charging_session: session(soc_from: 75, soc_to: 75, kwh: 20)))

    expect(page).to have_css('p', text: I18n.t('charging_sessions.soc_finding.mismatch.text'))
    expect(page).to have_css('p span.block', text: I18n.t('charging_sessions.soc_finding.mismatch.hint'))
  end
end
