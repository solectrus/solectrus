describe 'Cars Visits' do
  let(:home) { Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Home') }
  let(:work) { Place.create!(latitude: 50.906, longitude: 6.407, name: 'Work') }
  # Each day has a fresh summary, unless a spec says so
  let(:pending_days) { [] }

  def visit_at(place, from, to)
    started_at = Time.zone.parse(from)
    place.visits.create!(car: Car.configured.first, date: started_at.to_date, started_at:, ended_at: Time.zone.parse(to))
  end

  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
        'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
      ),
    )
    allow(Summary).to receive(:missing_or_stale_days_for).and_return(pending_days)
  end

  after { Sensor::Config.setup(ENV) }

  describe 'GET /cars/visits' do
    it 'forbids the list to a guest' do
      get cars_visits_path

      expect(response).to have_http_status(:forbidden)
    end

    context 'without the car page' do
      before { Setting.enable_car = false }
      after { Setting.enable_car = true }

      it 'goes to the home page' do
        login_as_admin
        get cars_visits_path

        expect(response).to redirect_to(root_path)
      end
    end

    context 'with a day without a fresh summary' do
      let(:pending_days) { [Date.current] }

      it 'builds the day first' do
        login_as_admin
        get cars_visits_path

        expect(response.body).to include('sequential-frames')
        expect(Summary).to have_received(:missing_or_stale_days_for).with(an_object_having_attributes(id: :all))
      end

      it 'keeps the current day as fresh as in a day' do
        login_as_admin
        get cars_visits_path

        expect(Summary).to have_received(:missing_or_stale_days_for).with(an_object_having_attributes(id: :day))
      end

      it 'builds only the days of a timeframe' do
        login_as_admin
        get cars_visits_path(timeframe: '2026-09')

        expect(Summary).to have_received(:missing_or_stale_days_for).once.with(an_object_having_attributes(id: :month))
      end
    end

    context 'with visits' do
      before do
        visit_at(home, '2026-09-21 18:00', '2026-09-22 00:00')
        visit_at(home, '2026-09-22 00:00', '2026-09-22 07:20')
        visit_at(work, '2026-09-22 07:25', '2026-09-22 16:00')
        login_as_admin
      end

      it 'lists each visit in one row, with the day of the end over midnight' do
        get cars_visits_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Home', 'Work', '07:25–16:00', '8 h 35 min', '13 h 20 min')
        expect(response.body).to include('18:00 – 22.09. 07:20')
        expect(response.body).to include(I18n.t('visits.name'))
      end

      it 'opens a place in the modal, and narrows the list to it with the chevron' do
        get cars_visits_path(timeframe: '2026-09')

        expect(response.body).to include(%(href="/settings/places/#{work.id}/edit"), 'data-turbo-frame="modal"')
        expect(response.body).to include(%(href="/cars/places/#{work.id}/visits/2026-09"), I18n.t('visits.filter_place'))
      end

      it 'lists the visits of one place, and keeps it for the timeframe' do
        get cars_visits_path(timeframe: '2026-09', place: work.id)

        expect(response.body).to include('07:25–16:00', I18n.t('visits.remove_filter'))
        expect(response.body).not_to include('13 h 20 min')
        # The chip of the place removes it
        expect(response.body).to include(%(href="/cars/visits/2026-09"))
        expect(response.body).to include(%(href="/cars/places/#{work.id}/visits/2026-08"))
        # The list of one place narrows no further
        expect(response.body).not_to include(I18n.t('visits.filter_place'))
      end

      it 'lists the visits that overlap a timeframe, each with its full time' do
        get cars_visits_path(timeframe: '2026-09-21')

        expect(response.body).to include('13 h 20 min', Timeframe.new('2026-09-21').localized)
        expect(response.body).not_to include('07:25–16:00')
      end

      it 'names only the times in the list of one day, and the day of a part outside it' do
        get cars_visits_path(timeframe: '2026-09-22')

        expect(response.body).to include('until 07:20', 'since 21.09. 18:00', '07:25–16:00')
        expect(response.body).not_to include('22.09.2026')
      end

      context 'with the latest position of the car' do
        before do
          state = Car::Live::State.new(
            car: Car.configured.first,
            soc: nil,
            range: nil,
            max_range: nil,
            odometer: nil,
            connected: nil,
            charging_power: nil,
            latitude: work.latitude,
            longitude: work.longitude,
          )
          allow(Car::Live).to receive(:new).and_return(instance_double(Car::Live, states: [state]))
        end

        it 'shows the latest visit without an end while the car is still there' do
          get cars_visits_path

          expect(response.body).to include('since 07:25')
          expect(response.body).not_to include('07:25–16:00')
        end

        it 'asks for no position in a timeframe before now' do
          get cars_visits_path(timeframe: '2026-09')

          expect(response.body).to include('07:25–16:00')
          expect(Car::Live).not_to have_received(:new)
        end
      end

      it 'lists the visits of one car, and keeps it for the link of a place' do
        car = Car.configured.first
        get cars_visits_path(car: car.id, timeframe: '2026-09')

        expect(response.body).to include('13 h 20 min', '8 h 35 min')
        expect(response.body).to include(%(href="/cars/#{car.id}/places/#{work.id}/visits/2026-09"))
      end

      it 'goes back to the map of the car page in the timeframe and with the car' do
        car = Car.configured.first
        get cars_visits_path(car: car.id, timeframe: '2026-09')

        expect(response.body).to include(%(href="#{CGI.escapeHTML(cars_home_path(sensor_name: 'car_location', timeframe: '2026-09', car: car.id))}"))
      end

      it 'offers "all" in the select of the list of one car' do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
            'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
            'INFLUX_SENSOR_CAR_LATITUDE_2' => 'Wartburg:latitude',
            'INFLUX_SENSOR_CAR_LONGITUDE_2' => 'Wartburg:longitude',
          ),
        )
        get '/cars/1/visits/2026-09'

        expect(response.body).to include('href="/cars/visits/2026-09"', 'href="/cars/2/visits/2026-09"')
      end

      it 'narrows the list of all cars to one car with the chevron' do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
            'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
            'INFLUX_SENSOR_CAR_LATITUDE_2' => 'Wartburg:latitude',
            'INFLUX_SENSOR_CAR_LONGITUDE_2' => 'Wartburg:longitude',
          ),
        )
        get cars_visits_path(timeframe: '2026-09')

        expect(response.body).to include(%(href="/cars/1/visits/2026-09"), I18n.t('visits.filter_car'))
      end

      it 'goes to "all" for a car that the page does not offer' do
        get cars_visits_path(car: 9, timeframe: '2026-09', place: work.id)

        expect(response).to redirect_to("/cars/places/#{work.id}/visits/2026-09")
      end
    end

    it 'loads the next page into its frame' do
      start = Time.zone.parse('2026-09-01 08:00')
      26.times { home.visits.create!(car: Car.configured.first, date: start.to_date, started_at: start + it.hours, ended_at: start + it.hours + 30.minutes) }
      login_as_admin
      get cars_visits_path

      expect(response.body).to include('id="visits_page_2"')

      get cars_visits_path(page: 2), headers: { 'Turbo-Frame' => 'visits_page_2' }

      expect(response.body).to include('<turbo-frame', 'id="visits_page_2"')
      expect(response.body).not_to include('visits_page_3')
    end
  end

  describe 'GET /cars/visits in the modal' do
    it 'renders the select of the list, which keeps the place' do
      login_as_admin
      get cars_visits_path(timeframe: '2026-09', place: work.id), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="modal"', %(data-timeframe-select--component-base-url-value="/cars/places/#{work.id}/visits"))
    end

    it 'forbids the select to a guest' do
      get cars_visits_path(timeframe: '2026-09'), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
