describe ChargingSession::SocFacts::Component, type: :component do
  it 'names the state of charge' do
    render_inline(described_class.new(charging_session: ChargingSession.new(kind: :wallbox, soc_from: 64, soc_to: 65), css_class: 'mt-3'))

    expect(page).to have_css('p.mt-3', text: I18n.t('charging_sessions.soc', range: '64 → 65%'))
  end

  it 'renders nothing without a state of charge' do
    render_inline(described_class.new(charging_session: ChargingSession.new(kind: :wallbox)))

    expect(page).to have_no_css('p')
  end
end
