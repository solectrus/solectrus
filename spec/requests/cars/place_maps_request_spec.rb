describe 'Cars Place map' do
  let(:home) { Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Home') }
  let(:work) { Place.create!(latitude: 50.906, longitude: 6.407, name: 'Work') }
  # The map loads into its frame over the list (see Car::MapOverlay::Component)
  let(:frame) { { 'Turbo-Frame' => Car::MapOverlay::Component::FRAME_ID } }

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
  end

  after { Sensor::Config.setup(ENV) }

  describe 'GET /cars/places/map' do
    it 'forbids the map to a visitor' do
      get cars_place_map_path, headers: frame

      expect(response).to have_http_status(:forbidden)
    end

    it 'leads to the list of the places without its frame' do
      login_as_admin
      get cars_place_map_path(timeframe: '2026-09')

      expect(response).to redirect_to('/cars/places/2026-09')
    end

    context 'with visits' do
      before do
        visit_at(home, '2026-09-21 18:00', '2026-09-22 00:00')
        visit_at(home, '2026-09-22 00:00', '2026-09-22 07:20')
        visit_at(work, '2026-09-22 07:25', '2026-09-22 16:00')
        login_as_admin
      end

      it 'shows the places over the list, the longest time first, without the content of their tooltips' do
        get cars_place_map_path(timeframe: '2026-09'), headers: frame

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('<turbo-frame id="car_map"', 'car--map-overlay--component', ">#{I18n.t('car_breakdown.places_map')}</h2>")
        expect(response.body).to include('car--map--component', "[[50.92263,6.40706,0.6084,#{home.id}],[50.906,6.407,0.3916,#{work.id}]]")
        expect(response.body).not_to include('Home')
        expect(response.body).to include(%(data-car--map--component-tooltip-url-value="/cars/places/:id/tooltip/2026-09"), %(data-car--map--component-target="loading"))
      end

      it 'shows a note without a place in the timeframe' do
        get cars_place_map_path(timeframe: '2025'), headers: frame

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('No locations')
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

        it 'shows the places of the selected car, and keeps the car for the tooltip' do
          car = Car.configured.first
          get cars_place_map_path(car: car.id, timeframe: '2026-09'), headers: frame

          expect(response.body).to include('[{&quot;places&quot;:', %(data-car--map--component-tooltip-url-value="/cars/#{car.id}/places/:id/tooltip/2026-09"))
        end

        it 'goes to "all" for a car that the page does not offer' do
          get cars_place_map_path(car: 9, timeframe: '2026-09'), headers: frame

          expect(response).to redirect_to('/cars/places/map/2026-09')
        end
      end
    end
  end
end
