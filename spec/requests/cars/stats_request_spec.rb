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
        get cars_stats_path(sensor_name: 'car_charging', timeframe: 'now'),
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
    end

    context 'with a driven period' do
      let(:day) { Date.new(2026, 6, 15) }
      let(:headers) { { 'Turbo-Frame' => 'random-turbo-frame' } }
      let(:env) do
        ENV.to_h.merge('INFLUX_SENSOR_CAR_MILEAGE_1' => 'Trabant:odometer', 'INFLUX_SENSOR_CAR_MILEAGE_2' => 'Wartburg:odometer')
      end

      def wallbox(day, kwh:, kwh_grid:, cost:, car_id: 1, hour: 12)
        start = day.in_time_zone.change(hour:)
        ChargingSession.create!(kind: :wallbox, car_id:, started_at: start, ended_at: start + 1.hour, kwh:, kwh_grid:, cost:)
      end

      before do
        travel_to Date.new(2026, 9, 23).in_time_zone.change(hour: 12)
        Sensor::Config.setup(env)
        Car.create!(id: 1, name: 'Trabant')
        Car.create!(id: 2, name: 'Wartburg')

        Summary.create!(charging_sessions_version: ChargingSession::Detection::VERSION, date: day, updated_at: 1.day.ago)
        SummaryValue.create!(date: day, field: :car_mileage_1, aggregation: :sum, value: 150)
        SummaryValue.create!(date: day, field: :car_mileage_2, aggregation: :sum, value: 50)

        wallbox(day, kwh: 30, kwh_grid: 10, cost: 5)
      end

      after { Sensor::Config.setup(ENV) }

      it 'shows the driving cost and names the charging cost' do
        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

        expect(response.body).to include(
          I18n.t('sensors.car_driving_costs'),
          I18n.t('sensors.car_charging_costs'),
        )
      end

      it 'offers the select of the car' do
        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

        expect(response.body).to include('Trabant', 'Wartburg', 'car=2')
      end

      it 'keeps the car in each link of the page' do
        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 2), headers:)

        expect(response.body).to include(cars_charts_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 2))
      end

      %w[x 5].each do |param|
        it "shows \"all\" for the parameter car=#{param}" do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: param), headers:)

          expect(response.body).not_to include('car=x', 'car=5')
          expect(response.body).to include('Trabant', 'Wartburg')
        end
      end

      context 'with a session that is not assigned' do
        before { wallbox(day, kwh: 7, kwh_grid: 7, cost: 2.1, car_id: nil, hour: 18) }

        it 'names its energy in the selection "all"' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

          expect(response.body).to include('1 charging session is not assigned', 'car=not_assigned')
        end

        it 'names nothing for one car' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 1), headers:)

          expect(response.body).not_to include('not assigned')
        end
      end

      context 'with the power splitter and an offsite session' do
        before do
          stub_feature(:car, :power_splitter)
          Sensor::Config.setup(env)

          ChargingSession.create!(
            kind: :offsite,
            car_id: 1,
            started_at: (day - 5).in_time_zone.change(hour: 12),
            kwh: 10,
            cost: 5,
          )
        end

        # The energy sources split the charge, not the drive
        it 'splits the charged energy by source' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 1), headers:)

          expect(response.body).to include(
            I18n.t('car_breakdown.home_pv'),
            I18n.t('car_breakdown.home_grid'),
            I18n.t('car_breakdown.offsite'),
          )
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
