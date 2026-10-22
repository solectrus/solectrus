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

  context 'without an odometer' do
    let(:state) { state_at(5.minutes.ago) }

    it 'shows the odometer as inactive boxes' do
      expect(html.css('span.font-mono').map { it.text.strip }).to eq(%w[– – – – – –])
    end
  end

  # A gauge for each car does not fit on a phone
  describe 'the battery' do
    let(:state) { state_at(5.minutes.ago) }

    it 'shows the only car as a gauge on every screen' do
      expect(html.css('svg[viewBox="30 0 340 300"]').size).to eq(1)
      expect(html.css('.sm\:hidden, .max-sm\:hidden')).to be_empty
    end

    context 'with two cars' do
      let(:other_state) { state_at(5.minutes.ago).with(car: Car.new(id: 2, active_from: Date.new(2020, 1, 1))) }
      let(:live) { instance_double(Car::Live, states: [state, other_state], wallbox_power: nil, wallbox_car_connected: nil, car_at_wallbox?: false) }

      it 'shows each car as a bar with a compact odometer on a phone' do
        bars = html.css('.flex-1.sm\:hidden')

        expect(bars.size).to eq(2)
        expect(bars.css('div.bg-car-battery[style="width: 80%"]').size).to eq(2)
        expect(bars.css('span.font-mono.w-\[1\\.375rem\]').size).to eq(12)
        expect(bars.css('svg[viewBox="30 0 340 300"]')).to be_empty
      end

      it 'parts the bars with a line' do
        expect(html.css('.sm\:hidden.border-t[aria-hidden="true"]').size).to eq(1)
      end

      it 'shows each car as a gauge on a wider screen' do
        expect(html.css('.max-sm\:hidden svg[viewBox="30 0 340 300"]').size).to eq(2)
      end
    end
  end

  describe 'the links to the charts of today' do
    let(:state) { state_at(5.minutes.ago).with(range: 208, odometer: 64_800) }
    let(:env) { { 'INFLUX_SENSOR_CAR_BATTERY_SOC_1' => 'Car:soc', 'INFLUX_SENSOR_CAR_RANGE_1' => 'Car:range', 'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Car:odometer' } }

    before do
      stub_const('ENV', ENV.to_h.merge(env))
      stub_feature(:car)
    end

    it 'links the state of charge, the range and the odometer of the car' do
      expect(html.css('a[href="/cars/1/car_battery_soc/day"]').text.strip).to eq('80 %')
      expect(html.css('a[href="/cars/1/car_range/day"]').text).to include('208')
      expect(html.css('a[href="/cars/1/car_distance/day"] span.font-mono').size).to eq(6)
    end

    # An estimated range has no chart
    context 'without a sensor of the range' do
      let(:env) { super().except('INFLUX_SENSOR_CAR_RANGE_1') }

      it 'links the range nowhere' do
        expect(html.css('a[href="/cars/1/car_range/day"]')).to be_empty
        expect(html.css('a[href="/cars/1/car_battery_soc/day"]')).to be_present
      end
    end
  end

  context 'without a car in use' do
    let(:live) { instance_double(Car::Live, states: [], wallbox_power: nil, wallbox_car_connected: nil, car_at_wallbox?: false) }

    before { allow(vc_test_controller).to receive(:admin?).and_return(admin) }

    context 'when logged in as admin' do
      let(:admin) { true }

      it 'shows a gray gauge with the note and a link to the settings of the cars' do
        expect(html.css('svg[viewBox="30 0 340 300"] path').size).to eq(1)
        expect(html.css('span.font-mono')).to be_empty
        expect(html.text).not_to include(I18n.t('sensors.car_range_short'))
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
