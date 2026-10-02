describe 'Car Home' do
  describe 'GET /cars' do
    it_behaves_like 'localized request', '/cars/car_charging/now'
    it_behaves_like 'sponsoring redirects', '/cars/car_charging/now'

    context 'without params :sensor_name and :timeframe' do
      it 'redirects to car charging' do
        get cars_home_path

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_charging', timeframe: 'now'),
        )
      end
    end

    context 'with a sensor of another page' do
      it 'redirects to car charging' do
        get cars_home_path(sensor_name: 'wallbox_power', timeframe: 'now')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_charging', timeframe: 'now'),
        )
      end
    end

    context 'with a car sensor' do
      it 'renders' do
        get cars_home_path(sensor_name: 'car_battery_soc_1', timeframe: 'now')

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with a past day that has a summary, but its window has none' do
      let(:day) { Date.new(2025, 6, 26) }

      before { Summary.create!(charging_sessions_version: ChargingSession::Detection::VERSION, date: day, updated_at: day + 2.days) }

      it 'builds the summaries of the window first' do
        get cars_home_path(sensor_name: 'car_charging', timeframe: day.iso8601)

        expect(response.body).to include("d_#{day - 14}_", "_#{day + 14}\"")
      end
    end

    context 'with a rate chart and a day' do
      it 'redirects to the default chart of that day' do
        get cars_home_path(sensor_name: 'car_consumption_rate', timeframe: '2026-06-26')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06-26'),
        )
      end
    end

    context 'with a rate chart and a month' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge('INFLUX_SENSOR_CAR_MILEAGE_1' => 'Trabant:odometer'),
        )
      end

      after { Sensor::Config.setup(ENV) }

      it 'renders' do
        get cars_home_path(sensor_name: 'car_cost_rate', timeframe: '2026-06')

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with the range chart' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge('INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range'),
        )
      end

      after { Sensor::Config.setup(ENV) }

      it 'renders the live view' do
        get cars_home_path(sensor_name: 'car_range_1', timeframe: 'now')

        expect(response).to have_http_status(:ok)
      end

      it 'redirects a month to the default chart of that month' do
        get cars_home_path(sensor_name: 'car_range_1', timeframe: '2026-06')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06'),
        )
      end
    end

    context 'with a sponsorship' do
      before { stub_feature(:car) }

      context 'without an odometer' do
        it 'asks for the missing sensors' do
          get cars_home_path(sensor_name: 'car_charging', timeframe: 'now')

          expect(response.body).to include('INFLUX_SENSOR_CAR_MILEAGE_1')
        end
      end

      context 'with an odometer and a wallbox' do
        before do
          Sensor::Config.setup(
            ENV.to_h.merge('INFLUX_SENSOR_CAR_MILEAGE_1' => 'Trabant:odometer'),
          )
        end

        after { Sensor::Config.setup(ENV) }

        it 'shows the stats' do
          get cars_home_path(sensor_name: 'car_charging', timeframe: 'now')

          expect(response.body).not_to include('INFLUX_SENSOR_CAR_MILEAGE_1')
        end
      end
    end

    context 'when the car page is disabled' do
      before { Setting.enable_car = false }
      after { Setting.enable_car = true }

      it 'redirects to the power balance' do
        get cars_home_path(sensor_name: 'car_charging', timeframe: 'now')

        expect(response).to redirect_to(balance_home_path)
      end
    end
  end
end
