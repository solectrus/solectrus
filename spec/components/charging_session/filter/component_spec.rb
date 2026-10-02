describe ChargingSession::Filter::Component, type: :component do
  let(:cars) { [Car.new(id: 1, color: '#ff0000')] }

  it 'adds "not assigned" and "guest" for the wallbox' do
    render_inline(described_class.new(kind: 'wallbox', timeframe: nil, cars:, current: '1'))

    expect(page).to have_css('a[aria-current="page"][href="/charging_sessions/wallbox?car=1"]', text: 'Car 1')
    expect(page).to have_link 'Not assigned', href: '/charging_sessions/wallbox?car=not_assigned'
    expect(page).to have_link 'Guests', href: '/charging_sessions/wallbox?car=guest'
  end

  it 'renders nothing for offsite with one car' do
    render_inline(described_class.new(kind: 'offsite', timeframe: nil, cars:, current: nil))

    expect(page).to have_no_css('nav')
  end
end
