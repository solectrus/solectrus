describe ChargingSession::Filter::Component, type: :component do
  let(:cars) { [Car.new(id: 1, color: '#ff0000')] }

  it 'adds "not assigned" and "guest" for the wallbox' do
    render_inline(described_class.new(kind: 'wallbox', timeframe: nil, cars:, current: '1'))

    expect(page).to have_css('a[aria-current="page"][href="/cars/1/charging_sessions/wallbox"]', text: 'Car 1')
    expect(page).to have_link 'Not assigned', href: '/cars/unassigned/charging_sessions/wallbox'
    expect(page).to have_link 'Guests', href: '/cars/guest/charging_sessions/wallbox'
    expect(page).to have_css('a.border-t[href="/cars/unassigned/charging_sessions/wallbox"] svg[data-icon="circle-question"]')
    expect(page).to have_css('a[href="/cars/guest/charging_sessions/wallbox"] svg[data-icon="user"]')
    expect(page).to have_css('option[selected][value="/cars/1/charging_sessions/wallbox"]')
  end

  it 'shows a car in its color' do
    render_inline(described_class.new(kind: 'wallbox', timeframe: nil, cars:, current: nil))

    expect(page).to have_css('a[href="/cars/1/charging_sessions/wallbox"] svg[data-icon="car"][style="color: #ff0000"]')
    expect(page).to have_css('option[selected][value="/cars/charging_sessions/wallbox"]')
  end

  it 'renders nothing for offsite with one car and without a state of charge' do
    allow(ChargingSession::OffsiteDetection).to receive(:enabled?).and_return(false)

    render_inline(described_class.new(kind: 'offsite', timeframe: nil, cars:, current: nil))

    expect(page).to have_no_select
  end

  it 'adds the proposals for offsite with a state of charge' do
    allow(ChargingSession::OffsiteDetection).to receive(:enabled?).and_return(true)

    render_inline(described_class.new(kind: 'offsite', timeframe: nil, cars:, current: 'proposals'))

    expect(page).to have_css('a.border-t[aria-current="page"][href="/cars/proposals/charging_sessions/offsite"]', text: 'Unconfirmed sessions')
    expect(page).to have_css('a[href="/cars/proposals/charging_sessions/offsite"] svg[data-icon="circle-question"]')
  end
end
