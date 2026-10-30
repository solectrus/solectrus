describe 'Admin-only sensors' do
  # Every page that takes the sensor from the URL. Only the admin sees an
  # admin-only sensor (see ParamsHandling), so a new page must refuse it to a
  # visitor, too. A route that does not take the sensor answers 404.
  routes =
    Rails.application.routes.routes.select do |route|
      route.verb == 'GET' && route.parts.include?(:sensor_name)
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

  routes.each do |route|
    it "refuses the location of a car to a visitor at #{route.path.spec}" do
      get route.format(
            sensor_name: 'car_latitude_1',
            timeframe: 'all',
            period: 'day',
            calc: 'sum',
            sort: 'desc',
          )

      expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    end
  end
end
