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

      context 'with the location of the car' do
        before do
          Sensor::Config.setup(
            ENV.to_h.merge(
              'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
              'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
            ),
          )
          add_influx_point(name: 'Trabant', fields: { 'latitude' => 50.92263, 'longitude' => 6.40706 })
          stub_request(:get, /nominatim/)
        end

        after { Sensor::Config.setup(ENV) }

        def request_live_view
          get cars_stats_path(timeframe: 'now'),
              headers: {
                'Turbo-Frame' => 'random-turbo-frame',
              }
        end

        it 'shows the name of the place to the admin, with a link to the map' do
          Place.create!(latitude: 50.92265, longitude: 6.4071, name: 'Home')
          login_as_admin
          request_live_view

          expect(response.body).to include('Home', cars_location_path(car: 1))
          expect(response.body).not_to include(cars_place_path(car: 1))
        end

        it 'loads the town of an unknown place into the badge, without waiting for Nominatim' do
          login_as_admin
          request_live_view

          expect(response.body).to include('h-[0.75em] w-[4.5em] rounded-full', cars_place_path(car: 1))
          expect(a_request(:get, /nominatim/)).not_to have_been_made
        end

        it 'shows a generic label without Nominatim' do
          allow(Rails.configuration.x).to receive(:nominatim_url).and_return(nil)
          login_as_admin
          request_live_view

          expect(response.body).to include('>Location</span>')
          expect(response.body).not_to include(cars_place_path(car: 1))
        end

        it 'hides the location from a guest' do
          request_live_view

          expect(response.body).not_to include(cars_location_path(car: 1))
        end
      end
    end

    context 'with a driven period' do
      let(:day) { Date.new(2026, 6, 15) }
      let(:headers) { { 'Turbo-Frame' => 'random-turbo-frame' } }
      let(:env) do
        ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer', 'INFLUX_SENSOR_CAR_ODOMETER_2' => 'Wartburg:odometer')
      end

      def wallbox(day, kwh:, kwh_grid:, cost:, car_id: 1, hour: 12)
        start = day.in_time_zone.change(hour:)
        ChargingSession.create!(kind: :wallbox, origin: :detection, car_id:, started_at: start, ended_at: start + 1.hour, kwh:, kwh_grid:, cost:)
      end

      before do
        travel_to Date.new(2026, 9, 23).in_time_zone.change(hour: 12)
        Sensor::Config.setup(env)
        Car.create!(id: 1, name: 'Trabant')
        Car.create!(id: 2, name: 'Wartburg')
        # Only the admin sees the names of the cars
        login_as_admin

        Summary.create!(steps: Summary::Steps.versions, date: day, updated_at: 1.day.ago)
        SummaryValue.create!(date: day, field: :car_odometer_1, aggregation: :sum, value: 150)
        SummaryValue.create!(date: day, field: :car_odometer_2, aggregation: :sum, value: 50)

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

      # The car page needs the summaries of the rate window around its days
      def summarize(dates)
        Summary.upsert_all(dates.map { { date: it, steps: Summary::Steps.versions, updated_at: 1.day.ago } }, unique_by: :date)
      end

      # The header of a tablet and of a desktop has the select
      it 'offers the select of the car in the header of the page' do
        summarize((day - 14)..(day + 14))
        get cars_home_path(sensor_name: 'car_charging', timeframe: day.to_s)

        expect(response.body).to include('name="car"', 'Trabant', 'Wartburg', '/cars/2/car_charging')
      end

      # The live view shows each car in use with its name
      it 'offers no select in the live view' do
        get cars_home_path(timeframe: 'now')

        expect(response.body).not_to include('name="car"')
      end

      # A phone has no room for the select in the header
      it 'has the select of a phone in the stats' do
        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

        expect(response.body).to include('name="car"')
      end

      describe 'the card of a phone' do
        def pressed_card
          html = Nokogiri::HTML4(response.body) # rubocop:disable Rails/ResponseParsedBody
          html.at_css('[data-car-cards-target=button][aria-pressed=true]')['data-car-cards-card-param']
        end

        def hidden_cards
          html = Nokogiri::HTML4(response.body) # rubocop:disable Rails/ResponseParsedBody
          html.css('[data-car-cards-target=charging], [data-car-cards-target=driving]')
              .select { it['class'].to_s.split.include?('max-sm:hidden') }
              .pluck('data-car-cards-target')
        end

        it 'shows the charging card without a choice' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

          expect(pressed_card).to eq('charging')
          expect(hidden_cards).to eq(['driving'])
        end

        it 'shows the card of the cookie' do
          cookies[Car::CardToggle::Component::COOKIE] = 'driving'
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

          expect(pressed_card).to eq('driving')
          expect(hidden_cards).to eq(['charging'])
        end
      end

      it 'keeps the car in each link of the page' do
        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 2), headers:)

        expect(response.body).to include(
          cars_charts_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 2),
          cars_home_path(sensor_name: 'car_charging', timeframe: (day + 1).to_s, car: 2),
          cars_home_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 2),
        )
      end

      it 'keeps the car out of the links to other pages' do
        get cars_home_path(timeframe: 'now', car: 2)

        expect(response.body).to include('/cars/2/')
        expect(response.body).not_to match(%r{href="(?:https?://[^/"]+)?/(?!cars/)[^"]*car=2})
      end

      it 'shows each car in the live view' do
        get(cars_stats_path(timeframe: 'now'), headers:)

        expect(response.body).to include('aria-label="Trabant"', 'aria-label="Wartburg"')
      end

      it 'shows a guest the cars by their number' do
        logout
        get(cars_stats_path(timeframe: 'now'), headers:)

        expect(response.body).to include('aria-label="Car 1"', 'aria-label="Car 2"')
        expect(response.body).not_to include('Trabant', 'Wartburg')
      end

      # The live view has no select, so a selected car changes nothing
      it 'shows each car in the live view also with a selected car' do
        get(cars_stats_path(timeframe: 'now', car: 2), headers:)

        expect(response.body).to include('aria-label="Trabant"', 'aria-label="Wartburg"')
      end

      context 'with the live view' do
        before { Car.find(1).update!(active_until: Date.yesterday) }

        # The name stands at the gauge, because the live view has no select
        it 'offers only the cars in use today, with the name' do
          get(cars_stats_path(timeframe: 'now'), headers:)

          expect(response.body).to include('aria-label="Wartburg"', '>Wartburg</span>')
          expect(response.body).not_to include('Trabant')
        end

        it 'shows "all" for a car that is not in use today' do
          get(cars_stats_path(timeframe: 'now', car: 1), headers:)

          expect(response.body).to include('aria-label="Wartburg"')
          expect(response.body).not_to include('Trabant', '/cars/1/')
        end
      end

      context 'with a car outside the timeframe' do
        before { Car.find(2).update!(active_from: day + 1) }

        it 'offers only the cars in use in the timeframe' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

          # The distance of the first car alone, 150 km and not 200 km
          expect(response.body).to include('>150</strong>')
          expect(response.body).not_to include('Wartburg', '/cars/2/')
        end

        it 'keeps the select with the one car of the timeframe' do
          summarize((day - 14)..(day + 14))
          get cars_home_path(sensor_name: 'car_charging', timeframe: day.to_s)

          # One choice is no choice, so the select does not open
          expect(response.body).to match(/<select[^>]* disabled[ =>]/)
          # The option of the native select shows the short name
          expect(response.body).to match(/<option[^>]*selected[^>]*>#{Car.find(1).short_name}</)
          expect(response.body).not_to include('Wartburg', 'All cars')
        end

        it 'offers both cars in a timeframe that holds both periods' do
          summarize(Date.new(2026, 5, 18)..Date.new(2026, 7, 14))
          get cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06')

          expect(response.body).to include('name="car"', 'Trabant', 'Wartburg')
          expect(response.body).not_to match(/<select[^>]* disabled[ =>]/)
        end
      end

      # The odometer gives the driving, but the charging does not need it
      context 'with a car without an odometer' do
        let(:env) do
          ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer', 'INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc')
        end

        before { wallbox(day, kwh: 20, kwh_grid: 5, cost: 4, car_id: 2, hour: 15) }

        it 'shows the charging of the car and no driving' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 2), headers:)

          expect(response.body).to include(I18n.t('car_breakdown.charging'), I18n.t('sensors.car_charging_costs'))
          expect(response.body).not_to include(I18n.t('car_breakdown.driving'), I18n.t('data.car_none_in_use'))
        end

        it 'shows the driving of the car with an odometer' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 1), headers:)

          expect(response.body).to include(I18n.t('car_breakdown.charging'), I18n.t('car_breakdown.driving'))
        end
      end

      # A missing value is no missing sensor, so the cards stay
      context 'with an odometer without a value in the timeframe' do
        before { wallbox(day + 1, kwh: 20, kwh_grid: 5, cost: 4) }

        it 'shows the charging and the driving without a distance' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: (day + 1).to_s, car: 1), headers:)

          expect(response.body).to include(I18n.t('car_breakdown.charging'), I18n.t('car_breakdown.driving'))
          expect(response.body).not_to include(I18n.t('data.car_none_in_use'))
        end
      end

      context 'without a car in the timeframe' do
        before { Car.find_each { it.update!(active_from: day + 1) } }

        it 'renders' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include('Trabant', 'Wartburg')
          expect(response.body).to include(I18n.t('data.car_none_in_use'))

          %w[car_charging car_charging_costs car_distance car_driving_costs car_cost_rate car_consumption_rate].each do |sensor_name|
            get(cars_charts_path(sensor_name:, timeframe: '2026-W24'), headers:)

            expect(response).to have_http_status(:ok)
          end
        end
      end

      # The stats frame is permanent, so each car needs a frame of its own
      it 'updates the stats frame of the car' do
        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 2), headers:)

        expect(response.body).to include(%(target="cars-stats-#{day}-2"))
      end

      # The texts of the chart menu. The menu sits in the template of a Turbo
      # stream, which the HTML5 parser of #parsed_body keeps out of the tree.
      def menu_items
        Nokogiri::HTML4(response.body).css('select[name=sensor-selector] option').map { it.text.strip } # rubocop:disable Rails/ResponseParsedBody
      end

      # The car select above the chart menu selects the car, so the menu
      # names no car. The distance shows each car, and the state of charge
      # needs one car.
      it 'offers the distance and no state of charge in the selection "all"' do
        get(cars_charts_path(sensor_name: 'car_charging', timeframe: '2026-06'), headers:)

        expect(menu_items).to include(I18n.t('sensors.car_distance_short'))
        expect(menu_items).not_to include(I18n.t('sensors.car_battery_soc_short'))
        expect(menu_items.join).not_to include('Trabant', 'Wartburg')
      end

      it 'offers the state of charge of the selected car without its name' do
        get(cars_charts_path(sensor_name: 'car_charging', timeframe: '2026-06', car: 1), headers:)

        expect(menu_items).to include(I18n.t('sensors.car_distance_short'), I18n.t('sensors.car_battery_soc_short'))
        expect(menu_items.join).not_to include('Trabant')
      end

      it 'sends the state of charge in the selection "all" to the default chart' do
        get cars_home_path(sensor_name: 'car_battery_soc', timeframe: day.to_s)

        expect(response).to redirect_to(cars_home_path(sensor_name: 'car_distance', timeframe: day.to_s))
      end

      it 'draws the distance of the selected car alone' do
        get(cars_charts_path(sensor_name: 'car_distance', timeframe: '2026-06', car: 2), headers:)

        expect(response.body).to include('Wartburg')
        expect(response.body).not_to include('Trabant')
      end

      [5, 9].each do |param|
        it "shows \"all\" for the car #{param}" do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: param), headers:)

          # The distance of both cars
          expect(response.body).not_to include("/cars/#{param}/")
          expect(response.body).to include('>200</strong>')
        end
      end

      context 'with a session that is not assigned' do
        before { wallbox(day, kwh: 7, kwh_grid: 7, cost: 2.1, car_id: nil, hour: 18) }

        it 'names its energy in the selection "all"' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

          expect(response.body).to include('1 session not assigned', 'data-icon="circle-question"')
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
            origin: :user,
            car_id: 1,
            started_at: (day - 5).in_time_zone.change(hour: 12),
            kwh: 10,
            cost: 5,
          )
        end

        # The energy sources split the charge, not the drive. The month holds
        # the offsite session, so each source has energy.
        it 'splits the charged energy by source' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.strftime('%Y-%m'), car: 1), headers:)

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
        get cars_stats_path(timeframe: 'now')

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
