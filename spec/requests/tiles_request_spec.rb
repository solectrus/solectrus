describe 'Tiles' do
  describe 'GET /tiles/:sensor_name/now' do
    it 'renders a live tile for an ordinary sensor' do
      add_influx_point(
        name: Sensor::Config.measurement(:house_power),
        fields: {
          Sensor::Config.field(:house_power) => 900.0,
        },
      )

      get '/tiles/house_power/now'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('tile-house_power-now')
    end

    # The sensor name comes straight from the URL, so it could name a power
    # split - which divides a period and has no reading of an instant. The
    # route already refuses it, because it is scoped to chart_enabled? sensors
    # and no power_splitter sensor defines a chart. Pinned here so a chart
    # added to a split later does not silently open a live path to it.
    it 'has no route for a power split' do
      stub_feature(:power_splitter)

      get '/tiles/house_power_grid/now'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /tiles/:sensor_name/:timeframe' do
    # A tile shows only a sensor of the installation, with its permission
    it 'returns not found for a sensor behind a sponsorship' do
      stub_feature

      get '/tiles/heatpump_heating_power/year'

      expect(response).to have_http_status(:not_found)
    end

    it 'renders the sensor with the sponsorship' do
      stub_feature(:heatpump)

      get '/tiles/heatpump_heating_power/year'

      expect(response).to have_http_status(:ok)
    end
  end

  # A visitor sees a chart of the car page up to the latest public day (see
  # Car::AdminOnlyDays)
  describe 'a chart of the car page' do
    before do
      travel_to Time.zone.local(2026, 9, 23, 12)
      Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER' => 'Trabant:odometer'))
      Current.cars = nil
    end

    after { Sensor::Config.setup(ENV) }

    %w[day 2026-09-22 week 2026-09].each do |timeframe|
      it "is not found for a visitor with #{timeframe}" do
        get "/tiles/car_distance/#{timeframe}"

        expect(response).to have_http_status(:not_found)
      end
    end

    it 'renders a period before for a visitor' do
      get '/tiles/car_distance/2026-09-21'

      expect(response).to have_http_status(:ok)
    end

    it 'renders today for the admin' do
      login_as_admin
      get '/tiles/car_distance/day'

      expect(response).to have_http_status(:ok)
    end
  end
end
