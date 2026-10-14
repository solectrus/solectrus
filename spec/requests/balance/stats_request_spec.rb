describe 'Stats' do
  describe 'GET /stats' do
    it_behaves_like 'localized request', '/stats/house_power/now'
    it_behaves_like 'sponsoring redirects', '/stats/house_power/now'

    context 'with turbo_frame request' do
      it 'renders' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: 'now'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with the home battery and one car in use' do
      before do
        Car.create!(id: 1)
        add_influx_point(name: Sensor::Config.measurement(:battery_soc), fields: { Sensor::Config.field(:battery_soc) => 64 })
        add_influx_point(name: Sensor::Config.measurement(:car_battery_soc_1), fields: { Sensor::Config.field(:car_battery_soc_1) => 78 })
      end

      it 'shows the state of charge of both' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: 'now'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(response.body).to include('soc-badge', '64%', '78%', cars_home_path(timeframe: 'now'))
      end
    end

    context 'with default request' do
      it 'redirects' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: 'now')

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
