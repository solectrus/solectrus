describe 'Car Charts' do
  describe 'GET /cars/charts' do
    {
      'car_consumption_rate' => %w[2026-W30 2026-06 2026 all],
      'car_cost_rate' => %w[2026-W30 2026-06 2026 all],
      'car_driving_costs' => %w[2026-W30 2026-06 2026 all],
    }.each do |sensor_name, timeframes|
      timeframes.each do |timeframe|
        context "with #{sensor_name} and timeframe #{timeframe}" do
          it 'renders' do
            get cars_charts_path(sensor_name:, timeframe:),
                headers: {
                  'Turbo-Frame' => 'random-turbo-frame',
                }

            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    context 'with the map of the places' do
      let(:headers) { { 'Turbo-Frame' => 'random-turbo-frame' } }

      before do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
            'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
          ),
        )
        # The visit of yesterday, from the daily build
        place = Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Home', labels: ['home'])
        PlaceVisit.create!(date: Date.yesterday, car: Car.configured.first, place:, started_at: Date.yesterday.beginning_of_day, ended_at: Date.yesterday.beginning_of_day + 1.hour)
      end

      after { Sensor::Config.setup(ENV) }

      it 'shows the places to the admin, without the content of their tooltips' do
        login_as_admin
        get(cars_charts_path(sensor_name: 'car_location', timeframe: 'all'), headers:)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('car--map--component', "[[50.92263,6.40706,1.0,#{Place.home.id}]]")
        expect(response.body).not_to include('Home')
        # The map loads the tooltip of a place with the car of the page
        expect(response.body).to include(%(data-car--map--component-tooltip-url-value="/cars/places/:id/tooltip/all"), %(data-car--map--component-target="loading"), 'class="flex h-[3lh] w-24')
        # The refresh of the stats keeps the map
        expect(response.body).to include(%(data-stats-with-chart--component-target="kept"))
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
          # The outer setup knew one car only
          Current.cars = nil
          login_as_admin
        end

        it 'shows the places of all cars without a color of a car' do
          get(cars_charts_path(sensor_name: 'car_location', timeframe: 'all'), headers:)

          expect(response.body).to include('[{&quot;places&quot;:')
        end

        it 'shows the places of the selected car without its color, and keeps the car for the tooltip' do
          car = Car.configured.first
          get(cars_charts_path(car: car.id, sensor_name: 'car_location', timeframe: 'all'), headers:)

          expect(response.body).to include('[{&quot;places&quot;:')
          expect(response.body).not_to include(car.display_color)
          expect(response.body).to include(%(data-car--map--component-tooltip-url-value="/cars/#{car.id}/places/:id/tooltip/all"))
        end
      end

      it 'shows a note to the admin without a place in the timeframe' do
        login_as_admin
        get(cars_charts_path(sensor_name: 'car_location', timeframe: 1.year.ago.year.to_s), headers:)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t('data.car_no_location'))
        expect(response.body).not_to include('car--map--component')
      end

      it 'offers the map in the chart menu of the admin' do
        login_as_admin
        get(cars_charts_path(sensor_name: 'car_charging', timeframe: 'all'), headers:)

        expect(response.body).to include(I18n.t('sensors.car_location'))
      end

      it 'shows a guest the map without the places, with a hint' do
        get(cars_charts_path(sensor_name: 'car_location', timeframe: 'all'), headers:)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('car--map--component', 'data-car--map--component-cars-value="[]"', 'Only visible to administrators')
        expect(response.body).not_to include('50.92263')
        expect(response.body).not_to include('tooltip-url-value')
      end

      it 'offers the map in the chart menu of a guest' do
        get(cars_charts_path(sensor_name: 'car_charging', timeframe: 'all'), headers:)

        expect(response.body).to include(I18n.t('sensors.car_location'))
      end
    end
  end
end
