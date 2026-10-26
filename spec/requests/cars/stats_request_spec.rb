describe 'Car Stats' do
  describe 'GET /cars/stats' do
    # The car page needs the summaries of the whole time, because the spans
    # of a calendar period read each day (see Car::Spans). Without them, each
    # request builds the summaries of years of days.
    def summarize
      dates = Rails.configuration.x.installation_date..Date.current
      Summary.upsert_all(dates.map { { date: it, updated_at: Time.current } }, unique_by: :date)
    end

    %w[now 2026 2026-09-22].each do |timeframe|
      context "with timeframe #{timeframe}" do
        it 'renders' do
          summarize
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

        expect(response.body).to include('Charging at 7.4 kW', 'aria-label="SOC 78 %"', 'style="width: 78%"')
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

        it 'loads the town of an unknown place into the row, without waiting for Nominatim' do
          login_as_admin
          request_live_view

          expect(response.body).to include('animate-pulse', cars_place_path(car: 1))
          expect(a_request(:get, /nominatim/)).not_to have_been_made
        end

        it 'shows the car on the road without Nominatim' do
          allow(Rails.configuration.x).to receive(:nominatim_url).and_return(nil)
          login_as_admin
          request_live_view

          expect(response.body).to include('On the road')
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

        summarize
        SummaryValue.create!(date: day, field: :car_odometer_1, aggregation: :sum, value: 150)
        SummaryValue.create!(date: day, field: :car_odometer_2, aggregation: :sum, value: 50)

        wallbox(day, kwh: 30, kwh_grid: 10, cost: 5)
      end

      after { Sensor::Config.setup(ENV) }

      # A day has the timeline of the day below the figures, in place of the
      # charts of the columns (see Car::DayTimeline::Component)
      it 'shows the timeline of a day in place of the charts' do
        get cars_home_path(timeframe: day.to_s)

        expect(response.body).to include("id=\"cars-timeline-#{day}\"")
        expect(response.body).not_to include('/cars/charts/')

        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)
        expect(response.body).to include("target=\"cars-timeline-#{day}\"", 'Course of the day')
      end

      # A column without a charging session or without a drive shows the
      # state of the car first, and else its first chart with empty axes
      context 'with a period without charging and driving' do
        let(:idle_month) { '2026-07' }

        it 'shows the first chart of each column without a sensor of the state' do
          allow(Sensor).to receive(:data?).and_return(true)
          get cars_home_path(timeframe: idle_month)

          expect(response.body).to include("/cars/charts/car_charging/#{idle_month}", "/cars/charts/car_distance/#{idle_month}")
        end

        context 'with the state of charge and the range' do
          let(:env) do
            super().merge('INFLUX_SENSOR_CAR_BATTERY_SOC_1' => 'Trabant:soc', 'INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range')
          end

          # A link chose the chart on purpose, so the empty chart of the
          # address shows
          it 'shows the chart of the address, also without a value' do
            allow(Sensor).to receive(:data?).and_return(true)
            get cars_home_path(sensor_name: 'car_distance', timeframe: idle_month, car: 1)

            expect(response.body).to include("/cars/1/charts/car_distance/#{idle_month}")
          end

          # The menu offers each chart of the column, also an empty one, so a
          # pick can go back to it
          it 'offers the empty charts in the menu' do
            get(cars_charts_path(sensor_name: 'car_max_range', timeframe: idle_month, car: 1), headers:)

            expect(response.body).to include("/cars/1/car_distance/#{idle_month}")
          end
        end

        it 'keeps the figures, without the link to the sessions' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: idle_month), headers:)

          boxes = Nokogiri::HTML5.fragment(response.body.gsub(%r{</?template>}, '')).css('section[aria-labelledby^="overview-"]')
          expect(boxes.size).to eq(2)
          expect(boxes.text).to include(I18n.t('sensors.car_charging_costs'), I18n.t('car_breakdown.cost_rate'))
          expect(boxes.css('a[href*="/charging_sessions/"]')).to be_empty
          expect(response.body).not_to include('The data is not enough')
        end
      end

      # The charging column shows its empty chart, and a phone shows the
      # driving, which has a value
      context 'with a period with a drive but without charging' do
        let(:drive_day) { Date.new(2026, 8, 10) }
        let(:drive_month) { '2026-08' }

        before { SummaryValue.create!(date: drive_day, field: :car_odometer_1, aggregation: :sum, value: 20) }

        it 'shows the first chart of each column, and the distance first on a phone' do
          allow(Sensor).to receive(:data?).and_return(true)
          get cars_home_path(timeframe: drive_month, car: 1)

          html = response.parsed_body
          columns = html.css('[data-car-overview-target="column"]')
          expect(columns.size).to eq(2)
          expect(response.body).to include("/cars/1/charts/car_charging/#{drive_month}", "/cars/1/charts/car_distance/#{drive_month}")
          expect(columns.find { it['data-active'] == 'true' }['data-car-overview-charts']).to start_with('car_distance')
        end

        it 'keeps the charging figures, which load their empty charts' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: drive_month, car: 1), headers:)

          charging = Nokogiri::HTML5.fragment(response.body.gsub(%r{</?template>}, '')).at_css('section[aria-labelledby="overview-charging"]')
          expect(charging.text).to include(I18n.t('sensors.car_charging_costs'))
          expect(charging.css('a[href*="/car_charging/"]')).not_to be_empty
        end
      end

      # Each column of the overview loads its figures (see Car::Section)
      it 'shows the charging cost and the rates of the driving' do
        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)
        expect(response.body).to include(I18n.t('sensors.car_charging_costs'))

        get(cars_stats_path(sensor_name: 'car_distance', timeframe: day.to_s), headers:)
        expect(response.body).to include(I18n.t('car_breakdown.cost_rate'), I18n.t('car_breakdown.consumption_rate'))
      end

      # The tooltip of a rate has the numbers that give it and what only
      # this rate means, and without a rate what is missing. The window of
      # the rates stands in the info icon alone.
      it 'explains the rates of the driving' do
        get(cars_stats_path(sensor_name: 'car_distance', timeframe: day.to_s, car: 1), headers:)

        expect(response.body).to include('Driving cost', 'Energy used', 'includes the charging losses')
        expect(response.body).not_to include('counts the charging cost of the 14 days')
        expect(response.body).not_to include('Prices are missing')
      end

      it 'names the missing prices of a cost rate' do
        ChargingSession.update_all(cost: nil) # rubocop:disable Rails/SkipsModelValidations
        get(cars_stats_path(sensor_name: 'car_distance', timeframe: day.to_s, car: 1), headers:)

        expect(response.body).to include('Prices are missing.')
      end

      # The header of a tablet and of a desktop has the select
      it 'offers the select of the car in the header of the page' do
        get cars_home_path(timeframe: day.to_s)

        expect(response.body).to include('name="car"', 'Trabant', 'Wartburg', "/cars/2/#{day}")
      end

      # The live view shows each car in use with its name
      it 'offers no select in the live view' do
        get cars_home_path(timeframe: 'now')

        expect(response.body).not_to include('name="car"')
      end

      # A phone has the choices as chips below the period
      it 'has the select of a phone in the header' do
        get cars_home_path(timeframe: day.to_s)

        expect(response.body).to include("id=\"cars-car-select-chips-#{day}\"")
      end

      # A day has no charts, so a month
      it 'keeps the car in each link of the overview' do
        wallbox(day, kwh: 10, kwh_grid: 5, cost: 2, car_id: 2, hour: 15)
        month = day.strftime('%Y-%m')

        get(cars_stats_path(sensor_name: 'car_charging', timeframe: month, car: 2), headers:)
        expect(response.body).to include(
          cars_home_path(sensor_name: 'car_charging', timeframe: month, car: 2),
          cars_home_path(sensor_name: 'car_charging_costs', timeframe: month, car: 2),
        )

        get(cars_stats_path(sensor_name: 'car_distance', timeframe: month, car: 2), headers:)
        expect(response.body).to include(cars_home_path(sensor_name: 'car_distance', timeframe: month, car: 2))
      end

      it 'keeps the car out of the links to other pages' do
        get cars_home_path(timeframe: day.to_s, car: 2)

        expect(response.body).to include('/cars/2/')
        expect(response.body).not_to match(%r{href="(?:https?://[^/"]+)?/(?!cars/)[^"]*car=2})
      end

      # The live view shows each car in use, so it selects none
      it 'redirects the live view of a car to the live view' do
        get cars_home_path(timeframe: 'now', car: 2)

        expect(response).to redirect_to('/cars/now')
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

        # The live view has no select, so each other timeframe takes its one
        # car in use
        it 'links a timeframe with one car to that car, otherwise to "all"' do
          get cars_home_path(timeframe: 'now')

          expect(response.body).to include(
            cars_home_path(timeframe: Date.current.to_s, car: 2),
            "#{cars_home_path(timeframe: 'all')}\"",
          )
        end

        # The way back: the live view selects no car
        it 'links to the live view without the car' do
          get cars_home_path(timeframe: day.to_s, car: 2)

          expect(response.body).to include('/cars/now"')
          expect(response.body).not_to include('/cars/2/now')
        end
      end

      context 'with a car outside the timeframe' do
        # The new period removes the summary of the day, and the build makes it
        # again without the second car
        before do
          Car.find(2).update!(active_from: day + 1)
          summarize
          SummaryValue.create!(date: day, field: :car_odometer_1, aggregation: :sum, value: 150)
        end

        it 'offers only the cars in use in the timeframe' do
          get(cars_stats_path(sensor_name: 'car_distance', timeframe: day.to_s), headers:)

          # The distance of the first car alone, 150 km and not 200 km
          expect(response.body).to include('>150</strong>')
          expect(response.body).not_to include('Wartburg', '/cars/2/')
        end

        # "all" adds the guest sessions to the one car
        it 'keeps the select with the one car of the timeframe and "all"' do
          get cars_home_path(timeframe: day.to_s)

          expect(response.body).not_to match(/<select[^>]* disabled[ =>]/)
          expect(response.body).to match(/<option[^>]*selected[^>]*>All cars</)
          # The option of the native select shows the short name
          expect(response.body).to match(/<option[^>]*>#{Car.find(1).short_name}</)
          expect(response.body).not_to include('Wartburg')
        end

        it 'offers both cars in a timeframe that holds both periods' do
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
          get(cars_stats_path(sensor_name: 'car_distance', timeframe: day.to_s, car: 1), headers:)

          expect(response.body).to include(I18n.t('car_breakdown.driving'))
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
        before do
          Car.find_each { it.update!(active_from: day + 1) }
          summarize
        end

        it 'renders' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include('Trabant', 'Wartburg')

          %w[car_charging car_charging_costs car_distance car_driving_costs car_cost_rate car_consumption_rate].each do |sensor_name|
            get(cars_charts_path(sensor_name:, timeframe: '2026-W24'), headers:)

            expect(response).to have_http_status(:ok)
          end
        end
      end

      # The stats frame is permanent, so each column and each car needs a
      # frame of its own. One request fills the frames of both columns.
      it 'updates the stats frame of each column and the car' do
        get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 2), headers:)

        expect(response.body).to include(%(target="cars-stats-charging-#{day}-2"), %(target="cars-stats-driving-#{day}-2"))
      end

      # The texts of the chart menu of a desktop, or of a phone. The menu sits
      # in the template of a Turbo stream, which the HTML5 parser of
      # #parsed_body keeps out of the tree.
      def menu_items(device = :desktop)
        wrapper = device == :desktop ? 'max-lg:hidden' : 'lg:hidden'
        Nokogiri::HTML4(response.body).css(%(div[class="#{wrapper}"] select[name=sensor-selector] option)).map { it.text.strip } # rubocop:disable Rails/ResponseParsedBody
      end

      # The car select above the chart menu selects the car, so the menu
      # names no car. The distance shows each car, and the state of charge
      # needs one car.
      # The menu of a desktop offers the charts of the column of the chart (see
      # Car::Section). A phone shows one chart, so its menu offers the charts
      # of both columns.
      it 'offers the charts of the column on a desktop, and of both on a phone' do
        get(cars_charts_path(sensor_name: 'car_charging', timeframe: '2026-06'), headers:)

        expect(menu_items).to contain_exactly(I18n.t('sensors.car_charging'), I18n.t('sensors.car_charging_costs'))
        expect(menu_items(:phone)).to include(I18n.t('sensors.car_charging'), I18n.t('sensors.car_distance_short'))
      end

      it 'offers the distance and no state of charge in the selection "all"' do
        get(cars_charts_path(sensor_name: 'car_distance', timeframe: '2026-06'), headers:)

        expect(menu_items).to include(I18n.t('sensors.car_distance_short'))
        expect(menu_items).not_to include(I18n.t('sensors.car_battery_soc_short'))
        expect(menu_items.join).not_to include('Trabant', 'Wartburg')
      end

      it 'offers the state of charge of the selected car without its name' do
        get(cars_charts_path(sensor_name: 'car_charging', timeframe: '2026-06', car: 1), headers:)

        expect(menu_items).to include(I18n.t('sensors.car_charging'), I18n.t('sensors.car_battery_soc_short'))
        expect(menu_items.join).not_to include('Trabant')
      end

      it 'sends the state of charge in the selection "all" to the overview' do
        get cars_home_path(sensor_name: 'car_battery_soc', timeframe: day.to_s)

        expect(response).to redirect_to(cars_home_path(sensor_name: nil, timeframe: day.to_s))
      end

      it 'draws the distance of the selected car alone' do
        get(cars_charts_path(sensor_name: 'car_distance', timeframe: '2026-06', car: 2), headers:)
        # The select beside it names each car
        chart = response.body[%r{<turbo-stream action="update" target="cars-chart-driving-2026-06">.*?</turbo-stream>}m]

        expect(chart).to include('Wartburg')
        expect(chart).not_to include('Trabant')
      end

      [5, 9].each do |param|
        it "shows \"all\" for the car #{param}" do
          get(cars_stats_path(sensor_name: 'car_distance', timeframe: day.to_s, car: param), headers:)

          # The distance of both cars
          expect(response.body).not_to include("/cars/#{param}/")
          expect(response.body).to include('>200</strong>')
        end
      end

      context 'with a guest session' do
        before do
          wallbox(day, kwh: 7, kwh_grid: 7, cost: 2.1, car_id: nil, hour: 18).update!(guest: true)
          summarize
        end

        it 'offers the guests in the select' do
          get cars_home_path(timeframe: day.to_s)

          expect(response.body).to include('Guest', "/cars/guest/#{day}")
        end

        # The guests have no car, so no driving and no sessions of a car
        it 'shows the charging of the guest alone, with the link to its page' do
          get(cars_stats_path(timeframe: day.strftime('%Y-%m'), car: 'guest'), headers:)

          expect(response.body).to include('>7</strong>', "/cars/guest/car_charging/#{day.strftime('%Y-%m')}")
          expect(response.body).not_to include(I18n.t('car_breakdown.driving'), I18n.t('data.car_none_in_use'))
        end

        # The charging cost of "all" holds the guest, which its tooltip names
        it 'names the cost of the guest in the tooltip of the charging cost of "all"' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.strftime('%Y-%m')), headers:)

          tooltip = Nokogiri::HTML4(response.body).at_css("a[href*='car_charging_costs'] [data-tooltip-target='html']").text # rubocop:disable Rails/ResponseParsedBody
          expect(tooltip).to include('of which guest', '2.10')
        end

        # The live view shows each car in use and no guests
        it 'goes from the guests to the live view without them' do
          get cars_home_path(timeframe: day.to_s, car: 'guest')

          expect(response.body).to include('/cars/now"')
          expect(response.body).not_to include('/cars/guest/now')
        end

        it 'redirects the live view of the guests to the live view' do
          get '/cars/guest/now'

          expect(response).to redirect_to('/cars/now')
        end

        # A chart loads in place, and each choice of the select keeps it
        it 'renders the select again with the chart that loads' do
          month = '2026-06'
          get(cars_charts_path(sensor_name: 'car_distance', timeframe: month, car: 1), headers:)

          expect(response.body).to include("target=\"cars-car-select-#{month}\"", "target=\"cars-car-select-chips-#{month}\"")
          expect(response.body).to include("/cars/guest/car_distance/#{month}")
        end

        # Each column loads its chart, but only the chart of the address
        # renders the navigation, so its links keep that chart
        it 'renders the navigation only for the chart of the address' do
          month = '2026-06'
          referer = "http://www.example.com/cars/1/car_distance/#{month}"

          get(cars_charts_path(sensor_name: 'car_charging', timeframe: month, car: 1), headers: headers.merge('Referer' => referer))
          expect(response.body).not_to include("target=\"cars-car-select-#{month}\"")

          get(cars_charts_path(sensor_name: 'car_distance', timeframe: month, car: 1), headers: headers.merge('Referer' => referer))
          expect(response.body).to include("target=\"cars-car-select-#{month}\"")

          get(cars_stats_path(sensor_name: 'car_charging', timeframe: month, car: 1), headers: headers.merge('Referer' => referer))
          expect(response.body).not_to include("target=\"cars-car-select-#{month}\"", '/cars/1/car_charging/2026-05')
        end

        it 'adds the guest to "all", but not to a car' do
          get(cars_stats_path(timeframe: day.to_s), headers:)
          expect(response.body).to include('>37</strong>')

          get(cars_stats_path(timeframe: day.to_s, car: 1), headers:)
          expect(response.body).to include('>30</strong>')
        end

        it 'offers the select also with one car in the installation' do
          Car.find(2).destroy!
          get cars_home_path(timeframe: day.to_s)

          expect(response.body).to include('name="car"', 'All cars', 'Trabant', 'Guest')
        end

        # The guest sessions are rare, so the one car leaves them out, also in
        # a timeframe with a guest session
        it 'links each other timeframe of the live view to the one car' do
          Sensor::Config.setup(env.except('INFLUX_SENSOR_CAR_ODOMETER_2'))
          get cars_home_path(timeframe: 'now')

          expect(response.body).to include(
            cars_home_path(timeframe: Date.current.to_s, car: 1),
            cars_home_path(timeframe: 'all', car: 1),
          )
        end

        it 'has no page of the driving' do
          get cars_home_path(sensor_name: 'car_distance', timeframe: day.to_s, car: 'guest')

          expect(response).to redirect_to(cars_home_path(sensor_name: nil, timeframe: day.to_s, car: 'guest'))
        end
      end

      context 'with a session that is not assigned' do
        before { wallbox(day, kwh: 7, kwh_grid: 7, cost: 2.1, car_id: nil, hour: 18) }

        # The link to the sessions has a dot, which a screen reader reads
        it 'names it in the selection "all", at the link to the sessions' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s), headers:)

          html = Nokogiri::HTML4(response.body) # rubocop:disable Rails/ResponseParsedBody
          link = html.at_css(%(a[href="#{cars_charging_sessions_path(kind: 'wallbox', timeframe: day.to_s, car: nil)}"]))
          expect(link.at_css('.sr-only').text).to eq(I18n.t('car_breakdown.unassigned', count: 1))
        end

        # It can be the charge of any car, so the admin sees it for one car too
        it 'names it for one car to the admin alone' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.to_s, car: 1), headers:)
          expect(response.body).to include(I18n.t('car_breakdown.unassigned', count: 1))

          logout
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

        # The tooltip of the charging cost has the cost of each source, and
        # what the cost of PV means
        it 'splits the charging cost by source' do
          get(cars_stats_path(sensor_name: 'car_charging', timeframe: day.strftime('%Y-%m'), car: 1), headers:)

          tooltip = Nokogiri::HTML4(response.body).at_css("a[href*='car_charging_costs'] [data-tooltip-target='html']").text # rubocop:disable Rails/ResponseParsedBody
          expect(tooltip).to include(I18n.t('car_breakdown.home_pv'), I18n.t('car_breakdown.offsite'), 'The cost of PV is the lost feed-in revenue.')
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
