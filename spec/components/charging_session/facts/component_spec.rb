describe ChargingSession::Facts::Component, type: :component do
  subject(:html) { render_inline(described_class.new(charging_session:)) }

  let(:charging_session) do
    ChargingSession.new(
      kind: :wallbox,
      started_at: Time.zone.local(2025, 12, 16, 15, 30),
      ended_at:,
      kwh: 10.918,
      kwh_grid: 9.826,
      cost: 2.83,
    )
  end
  let(:ended_at) { Time.zone.local(2025, 12, 16, 17, 30) }

  it 'shows the day and the time range' do
    expect(html.text.squish).to include('16. December 2025', '15:30–17:30')
  end

  it 'shows the energy, the cost and the PV share' do
    expect(html.text.squish).to include('10.9 kWh', '2.83', '10% from PV')
  end

  context 'without the power splitter' do
    before { charging_session.kwh_grid = nil }

    it 'shows no PV share' do
      expect(html.text).not_to include('%')
    end
  end
end
