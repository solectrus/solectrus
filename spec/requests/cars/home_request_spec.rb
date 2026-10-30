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
      it 'redirects to the overview' do
        get cars_home_path(sensor_name: 'wallbox_power', timeframe: '2026-06')

        expect(response).to redirect_to('/cars/2026-06')
      end
    end

    # The live view has no chart, so its address has no sensor
    context 'with the live view' do
      it 'renders without a sensor' do
        get cars_home_path(timeframe: 'now')

        expect(response).to have_http_status(:ok)
      end

      # Each car names the time of its latest reading instead
      it 'renders no status' do
        get cars_home_path(timeframe: 'now')

        expect(response.body).not_to include('id="cars-status-now"', 'id="cars-status-content-now"')
      end

      it 'redirects a sensor to the address without it' do
        get cars_home_path(sensor_name: 'car_battery_soc', timeframe: 'now')

        expect(response).to redirect_to('/cars/now')
      end

      it 'links to the live view without a sensor' do
        get cars_home_path(timeframe: '2026-06')

        expect(response.body).to include('/cars/now"')
      end

      context 'with an odometer' do
        before do
          Sensor::Config.setup(
            ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer'),
          )
        end

        after { Sensor::Config.setup(ENV) }

        it 'links to the overview of the other timeframes' do
          get cars_home_path(timeframe: 'now')

          expect(response.body).to include("/cars/#{Date.current.year}\"")
        end
      end
    end

    # The overview has no chart, so its address has no sensor
    context 'without a sensor in another timeframe' do
      it 'shows the overview' do
        get cars_home_path(timeframe: '2026-06-26')

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('/cars/charts/')
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

      # The frame of the timeframe is permanent, so another selection of the
      # same timeframe replaces it and its links keep the selection
      it 'gives the timeframe an id of the selection' do
        get cars_home_path(timeframe: '2026-06-26', car: 1)

        expect(response.parsed_body.at_css('turbo-frame#cars-timeframe-2026-06-26-1')).to be_present
      end
    end

    # The overview says so instead of its columns
    context 'with a period without a car in use' do
      before do
        stub_feature(:car)
        Car.create!(id: 1, active_from: Date.current)
        allow(Car::Report).to receive(:pending_days).and_return([])
        allow(Sensor).to receive(:data?).and_return(true)
      end

      it 'shows the note of the overview, without a chart' do
        get cars_home_path(timeframe: (Date.current.year - 1).to_s)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t('data.car_none_in_use'))
        expect(response.body).not_to include('/cars/stats/', '/cars/charts/')
      end

      it 'shows the chart of a period with the car' do
        start = Time.current.beginning_of_day
        ChargingSession.create!(kind: :wallbox, origin: :detection, car_id: 1, started_at: start, ended_at: start + 1.minute, kwh: 1, kwh_grid: 0, cost: 0)

        get cars_home_path(sensor_name: 'car_charging', timeframe: Date.current.year.to_s)

        expect(response.body).to include('/cars/charts/')
      end

      # One request fills the figures of each column (see Cars::StatsController)
      context 'with an odometer' do
        before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER' => 'Trabant:odometer')) }
        after { Sensor::Config.setup(ENV) }

        it 'loads the figures of both columns with one request' do
          get cars_home_path(sensor_name: 'car_charging', timeframe: Date.current.year.to_s)

          frames = response.parsed_body.css('[data-stats-with-chart--component-target=stats]')
          expect(frames.size).to eq(2)
          expect(frames.count { it['src'] }).to eq(1)
        end

        # The savings come with the figures, so a placeholder keeps their
        # place over the width of both columns (see Car::Report#savings?)
        it 'keeps the place of the savings while the figures load' do
          allow(Car::Report).to receive(:new).and_wrap_original do |original, *args, **options|
            original.call(*args, **options).tap { allow(it).to receive(:savings?).and_return(true) }
          end

          get cars_home_path(timeframe: Date.current.year.to_s)

          row = response.parsed_body.css('[data-turbo-permanent]').find { it.text.include?('Savings against a combustion car') }
          expect(row['class']).to include('lg:col-span-full')
          expect(response.parsed_body.css('section[aria-labelledby^="overview-"]').map(&:text).join).not_to include('Savings')
        end
      end
    end

    # Today and yesterday show when the car drove (see Car::AdminOnlyDays)
    context 'with a day that only the admin sees' do
      before do
        stub_feature(:car)
        Car.create!(id: 1)
        allow(Car::Report).to receive(:pending_days).and_return([])
        allow(Sensor).to receive(:data?).and_return(true)
      end

      it 'shows a visitor a note with the login' do
        get cars_home_path(timeframe: Date.yesterday.iso8601, car: 1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Administrator only', '/login?return_to=')
        expect(response.body).not_to include('stats-charging')
      end

      it 'shows the admin the day' do
        login_as_admin
        get cars_home_path(timeframe: Date.yesterday.iso8601, car: 1)

        expect(response.body).not_to include('Administrator only')
        expect(response.body).to include('stats-charging')
      end

      it 'shows a visitor an older day' do
        get cars_home_path(timeframe: (Date.current - 2).iso8601, car: 1)

        expect(response.body).not_to include('Administrator only')
      end

      # The data of the period ends with the day before yesterday
      it 'tells a visitor that a period leaves out these days, with the login' do
        get cars_home_path(timeframe: 'all', car: 1)

        notice = response.parsed_body.at_css('[role="note"]')
        expect(notice.text).to include('Without logging in, today and yesterday are left out for data protection.')
        expect(notice.at_css('a')['href']).to start_with('/login')
      end

      it 'tells the admin nothing' do
        login_as_admin
        get cars_home_path(timeframe: 'all', car: 1)

        expect(response.body).not_to include('Without logging in, today and yesterday are left out for data protection.')
      end
    end

    context 'with an hours timeframe' do
      before { Car.create!(id: 1) }

      # A day has no charts, so its address has no sensor
      it 'redirects to today and keeps the car' do
        get cars_home_path(sensor_name: 'car_battery_soc', timeframe: 'P24H', car: 1)

        expect(response).to redirect_to('/cars/1/day')
      end

      it 'offers no hours in the menu of today' do
        get cars_home_path(timeframe: Date.current.iso8601, car: 1)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('/P24H')
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

      before { Summary.create!(date: day, updated_at: day + 2.days) }

      # The spans of a day read each day (see Car::Spans)
      it 'builds the summaries of the whole time first' do
        get cars_home_path(timeframe: day.iso8601)

        expect(response.body).to include("d_#{Rails.configuration.x.installation_date}_", "_#{Date.current}\"")
      end
    end

    # A chart that cannot draw the timeframe gives way to the overview
    context 'with a rate chart and a day' do
      it 'redirects to the overview of that day' do
        get cars_home_path(sensor_name: 'car_consumption_rate', timeframe: '2026-06-26')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: nil, timeframe: '2026-06-26'),
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

    # Each chart needs the sensors of a selected car
    context 'with a chart of a sensor that the selected car does not have' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer', 'INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc'),
        )
        Car.create!(id: 1)
        Car.create!(id: 2)
      end

      after { Sensor::Config.setup(ENV) }

      # A day has the timeline of the day in place of the charts
      it 'redirects a day to its overview and keeps the car, with or without the sensor' do
        [1, 2].each do |car|
          get cars_home_path(sensor_name: 'car_distance', timeframe: '2026-06-26', car:)

          expect(response).to redirect_to(
            cars_home_path(sensor_name: nil, timeframe: '2026-06-26', car:),
          )
        end
      end

      # Without a chart of the driving, the page goes to the overview
      it 'redirects the distance of the car without an odometer' do
        get cars_home_path(sensor_name: 'car_distance', timeframe: '2026-06', car: 2)

        expect(response).to redirect_to(
          cars_home_path(sensor_name: nil, timeframe: '2026-06', car: 2),
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

      it 'goes from the charging of a day to the overview' do
        get cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06-26')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: nil, timeframe: '2026-06-26'),
        )
      end

      it 'keeps the charged energy of a month, which holds the offsite sessions' do
        get cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06')

        expect(response).to have_http_status(:ok)
      end
    end

    # A day has the timeline of the day in place of the charts, also where a
    # chart could draw it
    context 'with the charging cost of a day' do
      before { Car.create!(id: 1) }

      it 'redirects to the overview, also with the power splitter' do
        stub_feature(:car, :power_splitter)
        get cars_home_path(sensor_name: 'car_charging_costs', timeframe: '2026-06-26')

        expect(response).to redirect_to(
          cars_home_path(sensor_name: nil, timeframe: '2026-06-26'),
        )
      end
    end

    context 'with a sponsorship' do
      before { stub_feature(:car) }

      # The test configuration has the state of charge of the first car, but no
      # odometer
      context 'with the state of charge alone' do
        it 'shows the stats' do
          allow(Sensor).to receive(:data?).and_return(true)
          get cars_home_path(timeframe: 'now')

          expect(response.body).to include(cars_stats_path(timeframe: 'now'))
          expect(response.body).not_to include('INFLUX_SENSOR_CAR_ODOMETER_1')
        end

        it 'shows the overview' do
          get cars_home_path(timeframe: '2026-06')

          expect(response).to have_http_status(:ok)
        end
      end

      context 'without an odometer and a state of charge' do
        before do
          Sensor::Config.setup(
            ENV.to_h.except('INFLUX_SENSOR_CAR_BATTERY_SOC').merge('INFLUX_SENSOR_CAR_CONNECTED_1' => 'Trabant:connected'),
          )
        end

        after { Sensor::Config.setup(ENV) }

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
