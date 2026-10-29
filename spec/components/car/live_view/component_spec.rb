describe Car::LiveView::Component, type: :component do
  subject(:component) { described_class.new(live:) }

  let(:car) { Car.create!(id: 1) }
  let(:live) { instance_double(Car::Live, states: [state], wallbox_power: nil, wallbox_car_connected: nil, car_at_wallbox?: false) }
  let(:html) { render_inline(component) }

  def state_at(time)
    Car::Live::State.new(car:, soc: 80, range: nil, max_range: nil, odometer: nil, connected: nil, charging_power: nil, latitude: nil, longitude: nil, time:)
  end

  before { travel_to Time.zone.local(2026, 10, 7, 15, 40) }

  # The live view has no select of the car, so it names also the only car
  describe 'the name' do
    let(:state) { state_at(5.minutes.ago) }

    it 'shows the name of the car' do
      car.update!(name: 'Model Y', short_name: 'MY')

      expect(html.text).to include('Model Y')
    end

    it 'shows the short name of a car without a name' do
      car.update!(short_name: 'MY')

      expect(html.text).to include('MY')
      expect(html.text).not_to include('Car 1')
    end

    it 'shows a guest the default name' do
      car.update!(name: 'Model Y', short_name: 'MY')
      Current.car_names_hidden = true

      expect(html.text).to include('Car 1')
      expect(html.text).not_to include('Model Y')
      expect(html.text).not_to include('MY')
    end
  end

  # A car sensor holds its state at any age, so the live view always tells
  # how old it is, with the time of the reading in the tooltip
  describe 'the age of the reading' do
    def age = html.at_css("[data-controller='tooltip'][title^='Latest reading']")

    context 'with a reading of a few seconds ago' do
      let(:state) { state_at(20.seconds.ago) }

      it 'says just now' do
        expect(age.text.strip).to eq('just now')
      end
    end

    context 'with a recent reading' do
      let(:state) { state_at(5.minutes.ago) }

      it 'shows the minutes, and the time in the tooltip' do
        expect(age.text.strip).to eq('5 min ago')
        expect(age['title']).to eq('Latest reading at 15:35')
      end
    end

    context 'with a reading of today' do
      let(:state) { state_at(Time.zone.local(2026, 10, 7, 12, 5)) }

      it 'shows the hours' do
        expect(age.text.strip).to eq('3 h ago')
        expect(age['title']).to eq('Latest reading at 12:05')
      end
    end

    context 'with a reading of yesterday' do
      let(:state) { state_at(Time.zone.local(2026, 10, 6, 17, 10)) }

      it 'shows "Yesterday" and the time in the tooltip' do
        expect(age.text.strip).to eq('22 h ago')
        expect(age['title']).to eq('Latest reading yesterday at 17:10')
      end
    end

    context 'with a reading of six days ago' do
      let(:state) { state_at(Time.zone.local(2026, 10, 1, 18, 30)) }

      it 'shows the days, and the weekday and the time in the tooltip' do
        expect(age.text.strip).to eq('5 days ago')
        expect(age['title']).to eq('Latest reading on Thursday at 18:30')
      end
    end

    context 'with a reading of seven days ago' do
      let(:state) { state_at(Time.zone.local(2026, 9, 30, 18, 30)) }

      it 'shows the date and the time in the tooltip' do
        expect(age['title']).to eq('Latest reading on Sep 30 at 18:30')
      end
    end
  end

  describe 'the odometer' do
    let(:state) { state_at(5.minutes.ago).with(odometer: 65_086) }

    it 'shows a car without an odometer without its foot' do
      expect(html.text).not_to include('Odometer')
    end

    it 'shows the odometer at the foot' do
      allow(car).to receive(:sensor?).and_call_original
      allow(car).to receive(:sensor?).with(:car_odometer).and_return(true)

      expect(html.text.squish).to match(/Odometer\s*65,086\s*km/)
    end
  end

  describe 'the battery' do
    let(:state) { state_at(5.minutes.ago) }

    it 'shows the state of charge as a bar with the percent' do
      expect(html.css('div.bg-car-battery[style="width: 80%"]').size).to eq(1)
      expect(html.css('[role="img"][aria-label="SOC 80 %"]').size).to eq(1)
    end

    context 'with two cars' do
      let(:other_state) { state_at(5.minutes.ago).with(car: Car.new(id: 2, active_from: Date.new(2020, 1, 1))) }
      let(:live) { instance_double(Car::Live, states: [state, other_state], wallbox_power: nil, wallbox_car_connected: nil, car_at_wallbox?: false) }

      it 'shows a card for each car' do
        expect(html.css('section[aria-label]').pluck('aria-label')).to eq(['Car 1', 'Car 2'])
      end
    end
  end

  # The state of the plug as a cell of the list below the card
  describe 'the plug' do
    def plug_cell = html.css('section div').to_a.rfind { it.text.start_with?('Wallbox') }.element_children.last.text.squish

    let(:state) { state_at(5.minutes.ago).with(connected: true, charging_power:) }

    context 'when the car charges' do
      let(:charging_power) { 7_400 }

      it 'shows the charging power' do
        expect(plug_cell).to eq('Charging at 7.4 kW')
      end
    end

    context 'when the car does not charge' do
      let(:charging_power) { 0 }

      it 'shows the plug alone' do
        expect(plug_cell).to eq('Connected')
      end
    end

    # A car away from home cannot be at the wallbox, but at any other charger
    context 'when the car is away' do
      let(:charging_power) { 0 }

      def render_away(connected:)
        render_inline(described_class.new(live: instance_double(Car::Live, states: [state.with(away: true, connected:)], wallbox_power: nil, car_at_wallbox?: false)))
      end

      it 'shows the plug without the wallbox' do
        text = render_away(connected: true).text

        expect(text).to include('Plug', 'Connected')
        expect(text).not_to include('Wallbox')
      end

      it 'shows the plug without a connection' do
        expect(render_away(connected: false).text).to include('Plug', 'Not connected')
      end
    end
  end

  # The list below each card folds into one cell with the place and the plug
  describe 'the folded list' do
    let(:live) { instance_double(Car::Live, states:, wallbox_power: nil, wallbox_car_connected: nil, car_at_wallbox?: false) }
    let(:admin) { true }

    def other_car = @other_car ||= Car.new(id: 2, active_from: Date.new(2020, 1, 1))

    def state_of(each_car)
      state_at(5.minutes.ago).with(car: each_car, connected: true, charging_power: 0, odometer: 12_345)
    end

    def toggles = html.css('section[data-controller="car--live-card--component"] button[aria-controls]')

    before do
      allow(vc_test_controller).to receive(:admin?).and_return(admin)
      [car, other_car].each do |each_car|
        allow(each_car).to receive_messages(located?: true)
        allow(each_car).to receive(:sensor?).and_call_original
        allow(each_car).to receive(:sensor?).with(:car_odometer).and_return(true)
      end
    end

    context 'with two cars' do
      let(:states) { [state_of(car), state_of(other_car)] }

      it 'starts folded, with the place and the plug in the folded cell' do
        expect(html.css('section[data-open="false"]').size).to eq(2)
        expect(toggles.pluck('aria-expanded')).to eq(%w[false false false false])
        expect(toggles.first.text).to include('On the road', 'Connected')
        expect(html.css("##{toggles.first['aria-controls']}").text).to include('Odometer')
      end
    end

    context 'with one car' do
      let(:states) { [state_of(car)] }

      it 'starts unfolded' do
        expect(html.css('section[data-open="true"]').size).to eq(1)
        expect(toggles.pluck('aria-expanded')).to eq(%w[true true])
      end
    end

    # A guest sees no place and no map
    context 'with a guest' do
      let(:states) { [state_of(car), state_of(other_car)] }
      let(:admin) { false }

      it 'does not fold the list' do
        expect(toggles).to be_empty
        expect(html.css('section[data-open]')).to be_empty
        expect(html.text).to include('Odometer')
      end
    end
  end

  describe 'the wallbox' do
    let(:state) { state_at(5.minutes.ago).with(connected: false, charging_power: 0) }
    let(:data) { Sensor::Data::Single.new({ wallbox_power: 7_400 }, timeframe: Timeframe.now, times: { wallbox_power: 3.minutes.ago }) }
    let(:live) { instance_double(Car::Live, states: [state], wallbox_power: 7_400, car_at_wallbox?: false, data:) }

    it 'shows a card of the guest while it charges' do
      expect(html.css('section[aria-label="Guest"]').text).to include('charging at the wallbox')
    end
  end

  # The timeline of today shows the state of charge and the drives
  describe 'the links to today' do
    let(:state) { state_at(5.minutes.ago).with(range: 208, odometer: 64_800) }
    let(:env) { { 'INFLUX_SENSOR_CAR_BATTERY_SOC_1' => 'Car:soc', 'INFLUX_SENSOR_CAR_RANGE_1' => 'Car:range', 'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Car:odometer' } }

    before do
      stub_const('ENV', ENV.to_h.merge(env))
      stub_feature(:car)
    end

    def links = html.css('a[href="/cars/1/day"]').map { it.text.squish }

    it 'links the state of charge and the odometer of the car, but not the range' do
      expect(links).to include('80 %', a_string_including('64,800'))
      expect(links).not_to include(a_string_including('208'))
    end

    context 'without a sensor of the odometer' do
      let(:env) { super().except('INFLUX_SENSOR_CAR_ODOMETER_1') }

      it 'links the state of charge alone' do
        expect(links).to eq(['80 %'])
      end
    end
  end

  context 'without a car in use' do
    let(:live) { instance_double(Car::Live, states: [], wallbox_power: nil, wallbox_car_connected: nil, car_at_wallbox?: false) }

    before { allow(vc_test_controller).to receive(:admin?).and_return(admin) }

    context 'when logged in as admin' do
      let(:admin) { true }

      it 'shows the note and a link to the settings of the cars' do
        expect(html.text).to include(I18n.t('data.car_none_in_use_now'))
        expect(html.css('a[href="/settings/cars"]')).to be_present
      end
    end

    context 'when not logged in' do
      let(:admin) { false }

      it 'shows the note without a link' do
        expect(html.text).to include(I18n.t('data.car_none_in_use_now'))
        expect(html.css('a[href="/settings/cars"]')).to be_empty
      end
    end
  end
end
