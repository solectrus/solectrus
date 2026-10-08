describe 'Car Home' do
  describe 'GET /cars' do
    it_behaves_like 'localized request', '/cars/now'
    it_behaves_like 'sponsoring redirects', '/cars/now'

    context 'without params :sensor_name and :timeframe' do
      it 'redirects to the live view' do
        get cars_home_path

        expect(response).to redirect_to('/cars/now')
      end
    end

    context 'with a sensor of another page' do
      it 'redirects to the default chart' do
        get cars_home_path(sensor_name: 'wallbox_power', timeframe: '2026-06')

        expect(response).to redirect_to('/cars/car_charging/2026-06')
      end
    end

    # The live view has no chart, so its address has no sensor
    context 'with the live view' do
      it 'renders without a sensor' do
        get cars_home_path(timeframe: 'now')

        expect(response).to have_http_status(:ok)
      end

      it 'redirects a sensor to the address without it' do
        get cars_home_path(sensor_name: 'car_battery_soc', timeframe: 'now')

        expect(response).to redirect_to('/cars/now')
      end

      it 'links to the live view without a sensor' do
        get cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06')

        expect(response.body).to include('/cars/now"')
      end

      context 'with an odometer' do
        before do
          Sensor::Config.setup(
            ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer'),
          )
        end

        after { Sensor::Config.setup(ENV) }

        it 'links to the default chart of the other timeframes' do
          get cars_home_path(timeframe: 'now')

          expect(response.body).to include("/cars/car_distance/#{Date.current.year}\"")
        end
      end
    end

    context 'without a sensor in another timeframe' do
      it 'redirects to the default chart of that timeframe' do
        get cars_home_path(timeframe: '2026-06-26')

        expect(response).to redirect_to('/cars/car_charging/2026-06-26')
      end
    end

    context 'with a car that the page does not offer' do
      before { Car.create!(id: 1, active_until: Date.yesterday) }

      it 'redirects to "all"' do
        get cars_home_path(timeframe: 'now', car: 1)

        expect(response).to redirect_to('/cars/now')
      end

      it 'keeps the car in another timeframe' do
        get cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06', car: 1)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with an hours timeframe' do
      before { Car.create!(id: 1) }

      it 'redirects to today and keeps the sensor and the car' do
        get cars_home_path(sensor_name: 'car_battery_soc', timeframe: 'P24H', car: 1)

        expect(response).to redirect_to(cars_home_path(sensor_name: 'car_battery_soc', timeframe: 'day', car: 1))
      end
    end

    context 'with an unknown car' do
      it 'redirects to "all"' do
        get cars_home_path(timeframe: 'now', car: 9)

        expect(response).to redirect_to('/cars/now')
      end
    end

    context 'with a past day that has a summary, but its window has none' do
      let(:day) { Date.new(2025, 6, 26) }

      before { Summary.create!(steps: Summary::Steps.versions, date: day, updated_at: day + 2.days) }

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
          ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer'),
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

      it 'redirects a month to the default chart of that month' do
        get cars_home_path(sensor_name: 'car_range', timeframe: '2026-06')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06'),
        )
      end
    end

    # Each chart needs the sensors of a selected car
    context 'with a chart of a sensor that the selected car does not have' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer', 'INFLUX_SENSOR_CAR_RANGE_2' => 'Wartburg:range'),
        )
        Car.create!(id: 1)
        Car.create!(id: 2)
      end

      after { Sensor::Config.setup(ENV) }

      it 'redirects to the default chart and keeps the car' do
        get cars_home_path(sensor_name: 'car_range', timeframe: '2026-06-26', car: 1)

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_distance', timeframe: '2026-06-26', car: 1),
        )
      end

      it 'renders the chart of the car with the sensor' do
        get cars_home_path(sensor_name: 'car_range', timeframe: '2026-06-26', car: 2)

        expect(response).to have_http_status(:ok)
      end

      it 'redirects the distance of the car without an odometer' do
        get cars_home_path(sensor_name: 'car_distance', timeframe: '2026-06', car: 2)

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06', car: 2),
        )
      end
    end

    # A day without a wallbox has no curve of the charging power
    context 'without a wallbox' do
      before do
        Sensor::Config.setup(
          ENV.to_h.except('INFLUX_SENSOR_WALLBOX_POWER', 'INFLUX_SENSOR_WALLBOX_CAR_CONNECTED').merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer'),
        )
      end

      after { Sensor::Config.setup(ENV) }

      it 'takes the distance as the default chart of a day' do
        get cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06-26')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_distance', timeframe: '2026-06-26'),
        )
      end

      it 'keeps the charged energy of a month, which holds the offsite sessions' do
        get cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06')

        expect(response).to have_http_status(:ok)
      end
    end

    # The cost of the wallbox on a day comes from the split into PV and grid
    context 'with the charging cost of a day' do
      before { Car.create!(id: 1) }

      it 'redirects to the default chart without the power splitter' do
        stub_feature(:car)
        get cars_home_path(sensor_name: 'car_charging_costs', timeframe: '2026-06-26')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06-26'),
        )
      end

      it 'renders with the power splitter' do
        stub_feature(:car, :power_splitter)
        get cars_home_path(sensor_name: 'car_charging_costs', timeframe: '2026-06-26')

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with a sponsorship' do
      before { stub_feature(:car) }

      context 'without an odometer' do
        it 'asks for the missing sensors' do
          get cars_home_path(timeframe: 'now')

          expect(response.body).to include('INFLUX_SENSOR_CAR_ODOMETER_1')
        end
      end

      context 'with an odometer and a wallbox' do
        before do
          Sensor::Config.setup(
            ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer'),
          )
        end

        after { Sensor::Config.setup(ENV) }

        it 'shows the stats' do
          get cars_home_path(timeframe: 'now')

          expect(response.body).not_to include('INFLUX_SENSOR_CAR_ODOMETER_1')
        end

        # The sensors of a car report far less often than the sensors of the
        # house
        context 'with data' do
          before { allow(Sensor).to receive(:data?).and_return(true) }

          it 'shows no chart in the live view' do
            get cars_home_path(timeframe: 'now')

            expect(response.body).to include(cars_stats_path(timeframe: 'now'))
            expect(response.body).not_to include('/cars/charts/')
          end
        end
      end
    end

    context 'when the car page is disabled' do
      before { Setting.enable_car = false }
      after { Setting.enable_car = true }

      it 'redirects to the power balance' do
        get cars_home_path(timeframe: 'now')

        expect(response).to redirect_to(balance_home_path)
      end
    end
  end
end
