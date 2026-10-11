describe 'Personal sensors' do
  # Every page that takes the sensor from the URL. Only the admin sees a
  # personal sensor (see ParamsHandling), so a new page must refuse it to a
  # guest, too. A route that does not take the sensor answers 404. The car
  # page shows a guest the chart without its data (see
  # spec/requests/cars/charts_request_spec.rb).
  routes =
    Rails.application.routes.routes.select do |route|
      route.verb == 'GET' && route.parts.include?(:sensor_name) && !route.defaults[:controller].start_with?('cars/')
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
    it "refuses the location of a car to a guest at #{route.path.spec}" do
      get route.format(
            sensor_name: 'car_location',
            timeframe: 'all',
            period: 'day',
            calc: 'sum',
            sort: 'desc',
          )

      expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    end
  end
end
