describe TimeframePage::List do
  let(:timeframe) { Timeframe.new('2025') }

  it 'keeps the parameters in each address' do
    page = described_class.new(route: :cars_charging_sessions_path, params: { kind: 'wallbox', car: 'unassigned' })

    expect(page.path(timeframe)).to eq('/cars/unassigned/charging_sessions/wallbox/2025')
    expect(page.url_template).to eq('/cars/unassigned/charging_sessions/wallbox/:timeframe')
  end

  it 'offers the given kinds and no forecast' do
    page = described_class.new(route: :cars_visits_path, params: {}, kinds: %i[year all])

    expect(%i[year all hours].map { page.offers?(it) }).to eq([true, true, false])
    expect(page).not_to be_forecast
  end
end
