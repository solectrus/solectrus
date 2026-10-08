describe Car::LiveView::Component, type: :component do
  subject(:component) { described_class.new(live:, named: false) }

  let(:car) { Car.create!(id: 1) }
  let(:live) { instance_double(Car::Live, states: [state], wallbox_power: nil, wallbox_car_connected: nil, car_at_wallbox?: false) }
  let(:html) { render_inline(component) }

  def state_at(time)
    Car::Live::State.new(car:, soc: 80, range: nil, max_range: nil, odometer: nil, connected: nil, charging_power: nil, latitude: nil, longitude: nil, time:)
  end

  before { travel_to Time.zone.local(2026, 10, 7, 15, 40) }

  # A car sensor holds its state at any age, so the live view always tells
  # how old it is
  context 'with a recent reading' do
    let(:state) { state_at(5.minutes.ago) }

    it 'shows the time' do
      expect(html.text).to include('15:35')
    end
  end

  context 'with a reading of today' do
    let(:state) { state_at(Time.zone.local(2026, 10, 7, 12, 5)) }

    it 'shows the time, explained in its tooltip' do
      expect(html.at_css("[data-controller='tooltip'][title='Latest reading of the car']").text.strip).to eq('12:05')
    end
  end

  context 'with a reading of yesterday' do
    let(:state) { state_at(Time.zone.local(2026, 10, 6, 17, 10)) }

    it 'shows "Yesterday" and the time' do
      expect(html.text).to include('Yesterday, 17:10')
    end
  end

  context 'with a reading of six days ago' do
    let(:state) { state_at(Time.zone.local(2026, 10, 1, 18, 30)) }

    it 'shows the weekday and the time' do
      expect(html.text).to include('Thursday, 18:30')
    end
  end

  context 'with a reading of seven days ago' do
    let(:state) { state_at(Time.zone.local(2026, 9, 30, 18, 30)) }

    it 'shows the date and the time' do
      expect(html.text).to include('30 Sep 18:30')
    end
  end
end
