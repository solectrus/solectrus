describe 'Car Stats' do
  describe 'GET /cars/stats' do
    %w[now 2026 2026-09-22].each do |timeframe|
      context "with timeframe #{timeframe}" do
        it 'renders' do
          get cars_stats_path(sensor_name: 'car_charging', timeframe:),
              headers: {
                'Turbo-Frame' => 'random-turbo-frame',
              }

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with live values' do
      before do
        add_influx_point(
          name: Sensor::Config.measurement(:wallbox_power),
          fields: {
            Sensor::Config.field(:wallbox_power) => 7_400,
            Sensor::Config.field(:wallbox_car_connected) => 1,
          },
        )
        add_influx_point(
          name: Sensor::Config.measurement(:car_battery_soc_1),
          fields: {
            Sensor::Config.field(:car_battery_soc_1) => 78,
          },
        )
      end

      it 'shows the charging power and the state of charge' do
        get cars_stats_path(timeframe: 'now'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(response.body).to include(
          I18n.t('sensors.car_charging_power_short'),
          I18n.t('sensors.wallbox_car_connected_short'),
          I18n.t('sensors.car_battery_soc_short'),
          'stroke-dasharray="78 100"',
        )
      end

      context 'with the plug of the car' do
        before do
          Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_CONNECTED_1' => 'Trabant:plugged'))
          add_influx_point(name: 'Trabant', fields: { 'plugged' => 0 })
        end

        after { Sensor::Config.setup(ENV) }

        it 'shows the plug of the car in place of the plug of the wallbox' do
          get cars_stats_path(timeframe: 'now'),
              headers: {
                'Turbo-Frame' => 'random-turbo-frame',
              }

          expect(response.body).to include(I18n.t('sensors.wallbox_car_disconnected_short'))
          expect(response.body).not_to include(I18n.t('sensors.wallbox_car_connected_short'))
        end
      end
    end

    context 'with default request' do
      it 'redirects' do
        get cars_stats_path(sensor_name: 'car_charging', timeframe: 'now')

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
