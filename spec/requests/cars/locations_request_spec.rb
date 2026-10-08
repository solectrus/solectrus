describe 'Car Locations' do
  describe 'GET /cars/location/:car' do
    let(:headers) { { 'Turbo-Frame' => Car::Location::Component::FRAME_ID } }

    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
          'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
        ),
      )
      add_influx_point(name: 'Trabant', fields: { 'latitude' => 50.92263, 'longitude' => 6.40706 })
      stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/reverse}).to_return(body: { name: '', address: { town: 'Jülich' } }.to_json)
    end

    after { Sensor::Config.setup(ENV) }

    it 'shows the location of the car on a map in its frame to the admin' do
      login_as_admin
      get(cars_location_path(car: 1), headers:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="car_location"', 'Jülich', 'car--map--component', '50.92263')
    end

    # The car can be on the road, so only the daily build makes a place
    it 'makes no place, and asks Nominatim for its town once' do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      login_as_admin
      2.times { get(cars_location_path(car: 1), headers:) }

      expect(Place.count).to eq(0)
      expect(a_request(:get, /nominatim/)).to have_been_made.once
    end

    it 'names the place at the location' do
      Place.create!(latitude: 50.92265, longitude: 6.4071, name: 'Home')
      login_as_admin
      get(cars_location_path(car: 1), headers:)

      expect(response.body).to include('Home')
      expect(Place.count).to eq(1)
    end

    it 'forbids the location to a guest' do
      get(cars_location_path(car: 1), headers:)

      expect(response).to have_http_status(:forbidden)
    end

    it 'gives no car of a number without a configuration' do
      login_as_admin
      get(cars_location_path(car: 5), headers:)

      expect(response).to have_http_status(:not_found)
    end

    it 'sends a request without a frame to the car page' do
      login_as_admin
      get cars_location_path(car: 1)

      expect(response).to redirect_to(cars_home_path)
    end
  end
end
