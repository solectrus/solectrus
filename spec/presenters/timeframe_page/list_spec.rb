describe TimeframePage::List do
  let(:timeframe) { Timeframe.new('2025') }

  it 'keeps the parameters in each address' do
    page = described_class.new(route: :cars_charging_sessions_path, params: { kind: 'wallbox', car: 'unassigned' }, hours: true)

    expect(page.path(timeframe)).to eq('/cars/unassigned/charging_sessions/wallbox/2025')
    expect(page.base_url).to eq('/cars/unassigned/charging_sessions/wallbox')
  end

  it 'offers the hours as given and no forecast' do
    page = described_class.new(route: :cars_visits_path, params: {}, hours: false)

    expect(page).not_to be_hours
    expect(page).not_to be_forecast
  end
end
