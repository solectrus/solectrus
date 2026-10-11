describe 'Car Places' do
  describe 'GET /cars/location/:car/place' do
    let(:headers) { { 'Turbo-Frame' => 'car_place_1' } }

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

    it 'gives the town of the car in the frame of the badge to the admin' do
      login_as_admin
      get(cars_place_path(car: 1), headers:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="car_place_1"', 'Jülich', cars_location_path(car: 1))
      expect(response.body).not_to include(cars_place_path(car: 1))
    end

    it 'gives a generic label without an answer of Nominatim' do
      stub_request(:get, /nominatim/).to_return(status: 503)
      login_as_admin
      get(cars_place_path(car: 1), headers:)

      expect(response.body).to include('>Location</span>')
      expect(response.body).not_to include('animate-pulse')
    end

    it 'makes no place' do
      login_as_admin
      get(cars_place_path(car: 1), headers:)

      expect(Place.count).to eq(0)
    end

    it 'forbids the town to a guest' do
      get(cars_place_path(car: 1), headers:)

      expect(response).to have_http_status(:forbidden)
    end

    it 'gives no car of a number without a configuration' do
      login_as_admin
      get(cars_place_path(car: 5), headers:)

      expect(response).to have_http_status(:not_found)
    end

    it 'sends a request without a frame to the car page' do
      login_as_admin
      get cars_place_path(car: 1)

      expect(response).to redirect_to(cars_home_path)
    end
  end
end
