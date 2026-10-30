describe 'Cars Visits' do
  let(:home) { Place.create!(latitude: 50.92263, longitude: 1.40706, name: 'Home') }
  let(:work) { Place.create!(latitude: 50.906, longitude: 1.407, name: 'Work') }
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
    it 'forbids the list to a visitor' do
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

    it 'goes back to the car page in the timeframe and with the car' do
      login_as_admin
      get cars_visits_path(car: 1, timeframe: '2026-09')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('href="/cars/1/2026-09"')
    end

    it 'loads the next page into its frame' do
      start = Time.zone.parse('2026-09-01 08:00')
      26.times { home.visits.create!(car: Car.configured.first, date: start.to_date, started_at: start + it.hours, ended_at: start + it.hours + 30.minutes) }
      login_as_admin
      get cars_visits_path(page: 2), headers: { 'Turbo-Frame' => 'visits_page_2' }

      expect(response.body).to include('<turbo-frame', 'id="visits_page_2"')
      expect(response.body).not_to include('visits_page_3')
      # The rows lead back to the list
      expect(response.body).to include("return_to=#{CGI.escape(cars_visits_path)}")
      # The month goes on from the page before, so it has no second header
      expect(response.parsed_body.css('h3')).to be_empty
    end
  end

  describe 'GET /cars/places/:place/visits' do
    context 'with a day without a fresh summary' do
      let(:pending_days) { ((Date.current - 2)..Date.current).to_a }

      it 'builds the days first' do
        login_as_admin
        get cars_visits_path(place: work.id)

        expect(response.body).to include('sequential-frames')
        expect(Summary).to have_received(:missing_or_stale_days_for).with(an_object_having_attributes(id: :all))
      end

      it 'keeps the current day as fresh as in a day' do
        login_as_admin
        get cars_visits_path(place: work.id)

        expect(Summary).to have_received(:missing_or_stale_days_for).with(an_object_having_attributes(id: :day))
      end

      it 'builds only the days of a timeframe' do
        login_as_admin
        get cars_visits_path(timeframe: '2026-09', place: work.id)

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

      it 'lists the visits of the place, each in one row' do
        get cars_visits_path(timeframe: '2026-09', place: home.id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Home', '18:00 – 22.09. 07:20', '13:20 h')
        expect(response.body).not_to include('07:25–16:00')
      end

      it 'names the place as a filter of the list of the visits, which its x removes' do
        get cars_visits_path(timeframe: '2026-09', place: home.id)

        head = response.parsed_body.at_css('section > div')
        expect(head.text).to include('Home', I18n.t('car_breakdown.place_lists.visits'), '1 visit')
        expect(head.text).not_to include('at 1 place')
        expect(head.css('a').pluck('href')).to include('/cars/visits/2026-09', '/cars/places/2026-09')
        # The page keeps the pills of the lists, and no way back to the places
        expect(response.body).to include('href="/cars/places/2026-09"')
      end

      it 'opens a place, which leads back to the list' do
        get cars_visits_path(timeframe: '2026-09', place: work.id)

        expect(response.body).to include(%(href="/settings/places/#{work.id}/edit?return_to=%2Fcars%2Fplaces%2F#{work.id}%2Fvisits%2F2026-09"), %(data-nav-title="#{I18n.t('settings.places.edit')}"))
      end

      it 'names a place without a name by where it is, in italics' do
        work.update!(name: nil, geocoding: { 'address' => { 'suburb' => 'Braunsfeld', 'city' => 'Köln' } })
        get cars_visits_path(timeframe: '2026-09', place: work.id)

        expect(response.body).to include(%(class="italic text-muted" data-visit-place-name="#{work.id}">#{work.display_name}</span>))
        expect(response.parsed_body.at_css("[data-visit-place-locality='#{work.id}']").text).to be_empty
      end

      # The locality follows the name, after a comma
      it 'names the locality of a place with a name' do
        work.update!(geocoding: { 'address' => { 'suburb' => 'Braunsfeld', 'city' => 'Köln' } })
        get cars_visits_path(timeframe: '2026-09', place: work.id)

        expect(response.parsed_body.at_css("[data-visit-place-locality='#{work.id}']").text).to eq(', Braunsfeld, Köln')
      end

      it 'lists the visits that overlap a timeframe, each with its full time' do
        get cars_visits_path(timeframe: '2026-09-21', place: home.id)

        expect(response.body).to include('13:20 h', Timeframe.new('2026-09-21').localized)
      end

      it 'names only the times in the list of one day, and the day of a part outside it' do
        get cars_visits_path(timeframe: '2026-09-22', place: home.id)

        expect(response.body).to include('until 07:20, since 21.09. 18:00')
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
          get cars_visits_path(place: work.id)

          expect(response.body).to include('since 07:25')
          expect(response.body).not_to include('07:25–16:00')
        end

        it 'asks for no position in a timeframe before now' do
          get cars_visits_path(timeframe: '2026-09', place: work.id)

          expect(response.body).to include('07:25–16:00')
          expect(Car::Live).not_to have_received(:new)
        end
      end

      it 'goes back to the places in the timeframe and with the car' do
        car = Car.configured.first
        get cars_visits_path(car: car.id, timeframe: '2026-09', place: work.id)

        expect(response.body).to include(%(href="#{cars_visited_places_path(timeframe: '2026-09', car: car.id)}"))
      end

      it 'offers "all" in the select of the list of one car, and keeps the place' do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
            'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
            'INFLUX_SENSOR_CAR_LATITUDE_2' => 'Wartburg:latitude',
            'INFLUX_SENSOR_CAR_LONGITUDE_2' => 'Wartburg:longitude',
          ),
        )
        get "/cars/1/places/#{work.id}/visits/2026-09"

        expect(response.body).to include(%(href="/cars/places/#{work.id}/visits/2026-09"), %(href="/cars/2/places/#{work.id}/visits/2026-09"))
      end

      it 'goes to "all" for a car that the page does not offer' do
        get cars_visits_path(car: 9, timeframe: '2026-09', place: work.id)

        expect(response).to redirect_to("/cars/places/#{work.id}/visits/2026-09")
      end

      it 'passes its address to the form of a place, as the browser shows it' do
        get "/cars/places/#{work.id}/visits/all"

        expect(response.body).to include("return_to=%2Fcars%2Fplaces%2F#{work.id}%2Fvisits%2Fall\"")
      end

      describe 'the groups' do
        def headers = response.parsed_body.css('h3').map { it.text.strip }

        it 'groups a long list by month' do
          get cars_visits_path(place: home.id)

          expect(headers).to eq([I18n.l(Date.new(2026, 9, 1), format: :month)])
        end

        it 'opens the list of a group from its header, with the place' do
          get cars_visits_path(place: home.id)

          expect(response.parsed_body.css('h3 a').pluck('href')).to eq(["/cars/places/#{home.id}/visits/2026-09"])
        end

        it 'groups the list of a month by week' do
          get cars_visits_path(timeframe: '2026-09', place: home.id)

          expect(headers).to eq([I18n.l(Date.new(2026, 9, 21), format: :week)])
        end

        it 'groups the list of a week by day' do
          visit_at(home, '2026-09-23 18:00', '2026-09-23 19:00')
          get cars_visits_path(timeframe: '2026-W39', place: home.id)

          expect(headers).to eq([I18n.l(Date.new(2026, 9, 23), format: '%A'), I18n.l(Date.new(2026, 9, 21), format: '%A')])
        end

        it 'puts a visit that starts before the timeframe in its first group' do
          get cars_visits_path(timeframe: '2026-09-22', place: home.id)

          expect(headers).to eq([I18n.l(Date.new(2026, 9, 22), format: '%A')])
        end

        it 'gives the header of a day no link to the same list' do
          get cars_visits_path(timeframe: '2026-09-22', place: home.id)

          expect(response.parsed_body.css('h3 a')).to be_empty
        end

        it 'links the header of a day in the list of a week' do
          visit_at(home, '2026-09-23 18:00', '2026-09-23 19:00')
          get cars_visits_path(timeframe: '2026-W39', place: home.id)

          expect(response.parsed_body.css('h3 a').size).to eq(2)
        end
      end
    end
  end

  describe 'GET /cars/visits in the modal' do
    it 'renders the select of the list, which keeps the place' do
      login_as_admin
      get cars_visits_path(timeframe: '2026-09', place: work.id, select: 1), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="modal"', %(data-timeframe--select--component-url-template-value="/cars/places/#{work.id}/visits/:timeframe"))
    end

    it 'forbids the select to a visitor' do
      get cars_visits_path(timeframe: '2026-09'), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
