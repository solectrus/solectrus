describe 'Place tooltips' do
  describe 'GET /cars/places/:place/tooltip/:timeframe' do
    let(:place) { Place.create!(latitude: 50.92263, longitude: 6.40706) }
    let(:day) { 2.days.ago.beginning_of_day }

    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
          'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
        ),
      )
      stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/reverse})
        .to_return(body: { name: '', address: { town: 'Jülich' } }.to_json)
    end

    after { Sensor::Config.setup(ENV) }

    def visit_at(place, from, hours, car: Car.configured.first)
      PlaceVisit.create!(date: from.to_date, car:, place:, started_at: from, ended_at: from + hours.hours, seconds: hours * 3600)
    end

    it 'forbids the tooltip to a guest' do
      get cars_place_tooltip_path(place:, timeframe: 'all')

      expect(response).to have_http_status(:forbidden)
      expect(a_request(:get, /nominatim/)).not_to have_been_made
    end

    it 'names a place without a name after its town, once from Nominatim' do
      login_as_admin
      2.times { get cars_place_tooltip_path(place:, timeframe: 'all') }

      expect(response.body).to include('Jülich')
      expect(a_request(:get, /nominatim/)).to have_been_made.once
    end

    it 'gives the visits, the time and the links of the place, without a layout' do
      place.update!(name: 'Work')
      # A visit across midnight has two rows and counts once
      PlaceVisit.create!(date: day.to_date - 1, car: Car.configured.first, place:, started_at: day - 2.hours, ended_at: day, seconds: 7200)
      visit_at(place, day, 1)
      visit_at(place, day + 8.hours, 1)
      login_as_admin
      get cars_place_tooltip_path(place:, timeframe: 'all')

      expect(response.body).not_to include('<html')
      expect(response.body).to include('class="flex items-center gap-1.5 font-semibold"')
      expect(response.body).to include('Work', '4 h', %(href="/cars/places/#{place.id}/visits"))
      expect(response.body).to match(/2 (visits|Besuche)/)
      expect(response.body).to include(%(href="/settings/places/#{place.id}/edit"), 'google.com/maps/search/')
      # A single car names its car, too
      expect(response.body).to include(Car.configured.first.display_name, 'class="size-2.5 shrink-0')
    end

    it 'names the day of a single visit' do
      visit_at(place, Time.zone.local(2026, 9, 3, 10), 1)
      login_as_admin
      get cars_place_tooltip_path(place:, timeframe: '2026-09')

      expect(response.body).to match(/(2026-09-03|03\.09\.2026)/)
      expect(response.body).to include(%(href="/cars/places/#{place.id}/visits/2026-09"))
    end

    it 'gives home neither the visits nor the time' do
      place.update!(name: 'Home', labels: ['home'])
      visit_at(place, day, 1)
      login_as_admin
      get cars_place_tooltip_path(place:, timeframe: 'all')

      expect(response.body).to include('Home', 'data-icon="house"')
      expect(response.body).not_to include('/visits')
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
        first, second = Car.configured.first(2)
        first.update!(name: 'Trabant')
        second.update!(name: 'Wartburg')
        visit_at(place, day, 1, car: first)
        visit_at(place, day + 2.hours, 2, car: second)
        login_as_admin
      end

      it 'counts the visits of all cars, and names the cars, the car with the most time first' do
        get cars_place_tooltip_path(place:, timeframe: 'all')

        expect(response.body).to match(/2 (visits|Besuche)/)
        expect(response.body).to include('3 h', %(href="/cars/places/#{place.id}/visits"))
        expect(response.body.index('Wartburg')).to be < response.body.index('Trabant')
        expect(response.body).to include('class="size-2.5 shrink-0')
      end

      it 'counts the visits of the selected car, and names it' do
        car = Car.configured.first
        get cars_place_tooltip_path(car: car.id, place:, timeframe: 'all')

        expect(response.body).to include('1 h', %(href="/cars/#{car.id}/places/#{place.id}/visits"), 'Trabant')
        expect(response.body).not_to include('Wartburg')
      end
    end
  end
end
