describe 'Cars Place map' do
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

  describe 'GET /cars/places' do
    it 'forbids the map to a guest' do
      get cars_place_map_path

      expect(response).to have_http_status(:forbidden)
    end

    context 'with a day without a fresh summary' do
      let(:pending_days) { (Date.new(2026, 9, 20)..Date.new(2026, 9, 22)).to_a }

      it 'builds the days of the timeframe first' do
        login_as_admin
        get cars_place_map_path(timeframe: '2026-09')

        expect(response.body).to include('sequential-frames')
        expect(response.body).not_to include('car--map--component')
        expect(Summary).to have_received(:missing_or_stale_days_for).with(an_object_having_attributes(id: :month))
      end
    end

    context 'with visits' do
      before do
        visit_at(home, '2026-09-21 18:00', '2026-09-22 00:00')
        visit_at(home, '2026-09-22 00:00', '2026-09-22 07:20')
        visit_at(work, '2026-09-22 07:25', '2026-09-22 16:00')
        login_as_admin
      end

      it 'shows the places, the longest time first, without the content of their tooltips' do
        get cars_place_map_path(timeframe: '2026-09')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('car--map--component', "[[50.92263,6.40706,0.6084,#{home.id}],[50.906,6.407,0.3916,#{work.id}]]")
        expect(response.body).not_to include('Home')
        expect(response.body).to include(%(data-car--map--component-tooltip-url-value="/cars/places/:id/tooltip/2026-09"), %(data-car--map--component-target="loading"))
        expect(response.body).to include(I18n.t('car_breakdown.places'))
      end

      it 'keeps the map for another timeframe, and goes back to the car page' do
        get cars_place_map_path(timeframe: '2026-09')

        expect(response.body).to include('href="/cars/places/2026-08"')
        # The header offers the visits beside the map
        expect(response.body).to include('href="/cars/visits/2026-09"', I18n.t('visits.name'))
        expect(response.body).to include(%(href="#{CGI.escapeHTML(cars_home_path(sensor_name: 'car_distance', timeframe: '2026-09', car: nil))}"))
      end

      it 'shows a note without a place in the timeframe' do
        get cars_place_map_path(timeframe: '2025')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('No location in the selected period')
        expect(response.body).not_to include('car--map--component')
      end

      context 'with two cars' do
        before do
          Sensor::Config.setup(
            ENV.to_h.merge(
              'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
              'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
              'INFLUX_SENSOR_CAR_LATITUDE_2' => 'Wartburg:latitude',
              'INFLUX_SENSOR_CAR_LONGITUDE_2' => 'Wartburg:longitude',
            ),
          )
          Current.cars = nil
        end

        it 'shows the places of the selected car, and keeps the car for the tooltip and the select' do
          car = Car.configured.first
          get cars_place_map_path(car: car.id, timeframe: '2026-09')

          expect(response.body).to include('[{&quot;places&quot;:', %(data-car--map--component-tooltip-url-value="/cars/#{car.id}/places/:id/tooltip/2026-09"))
          expect(response.body).to include('href="/cars/places/2026-09"', 'href="/cars/2/places/2026-09"')
        end

        it 'goes to "all" for a car that the page does not offer' do
          get cars_place_map_path(car: 9, timeframe: '2026-09')

          expect(response).to redirect_to('/cars/places/2026-09')
        end
      end
    end
  end

  describe 'GET /cars/places in the modal' do
    it 'renders the select of the map' do
      login_as_admin
      get cars_place_map_path(timeframe: '2026-09'), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="modal"', 'data-timeframe--select--component-url-template-value="/cars/places/:timeframe"')
    end
  end
end
