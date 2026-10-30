describe 'Cars Savings' do
  let(:car) { Car.configured.first }
  let(:fuel_prices) { instance_double(Car::FuelPrices, any?: true) }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  before do
    travel_to Date.new(2026, 9, 23).in_time_zone.change(hour: 12)
    allow(Car::Report).to receive(:pending_days).and_return([])
    allow(Car::FuelPrices).to receive(:new).and_return(fuel_prices)
    allow(fuel_prices).to receive(:at).and_return(2.0)
    allow(fuel_prices).to receive(:series) { |dates| [[dates.begin, 1.9], [dates.end, 2.1]] }

    # The odometer reads since December, so each window starts before the
    # charges
    summary(Date.new(2025, 12, 1), :car_odometer_1, :sum, 0)

    # 30 kWh for 4.60 EUR, and 150 km two days later
    start = Date.new(2026, 1, 10).in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: start, ended_at: start + 1.hour, kwh: 30, kwh_grid: 10, cost: 4.6, cost_grid: 3.0)
    summary(Date.new(2026, 1, 12), :car_odometer_1, :sum, 150)
  end

  # The rows of the tables as the details show them, each with its cells.
  # `summary` gives the rows that show only without the details instead.
  def table_rows(summary: false) = response.parsed_body.css('tr').select { it['class'].to_s.include?('group-data-expanded/details:hidden') == summary }

  def row_text(row) = row.css('td, th').map { it.text.squish }.compact_blank.join(' ')

  def rows = table_rows.map { row_text(it) }

  # The data of a chart, by default the chart of the periods, nil without one
  def chart_data(chart = 'comparison-chart')
    script = response.parsed_body.at_css("script[data-car--#{chart}--component-target=\"data\"]")
    JSON.parse(script.text) if script
  end

  # The title of the chart of the periods, which the chart draws itself
  def chart_title = response.parsed_body.at_css('[data-car--comparison-chart--component-title-value]')['data-car--comparison-chart--component-title-value']

  # The page asks for the comparison in its frame
  def get_comparison(path) = get(path, headers: { 'Turbo-Frame' => 'comparison' })

  # The warnings of the comparison, each with its text
  def warnings = response.parsed_body.css('[role="status"] li').map { it.text.squish }

  def hrefs = response.parsed_body.css('a').pluck('href')

  context 'with a visitor' do
    before { car.update!(active_from: Date.new(2025, 1, 1), fuel_type: 'petrol', fuel_consumption: 8, combustion_tax: 365) }

    # Like the car page, the comparison is open to everyone. The payments
    # behind it and the settings stay with the admin. A visitor without the
    # admin login sees the data up to the latest public day, so 264 days of
    # 2026 count.
    it 'shows the comparison without a link to the payments or the settings' do
      car.payments.create!(category: :insurance, date: Date.new(2026, 4, 20), amount: 365)

      get_comparison cars_savings_path(timeframe: '2026')

      expect(response).to have_http_status(:ok)
      expect(rows).to include('+ Insurance 264 €')
      expect(hrefs.grep(%r{\A/settings})).to be_empty
    end

    # The link of the menu leaves out the car and the timeframe of the page
    it 'is in the menu' do
      get cars_savings_path(timeframe: '2025', car: car.id)

      expect(hrefs).to include('/cars/savings')
    end

    # Like the car page, the visitor sees the data up to the latest public day.
    # The drive of yesterday is left out, so the month has no distance.
    it 'leaves out today and yesterday, which a note says' do
      travel_to Date.new(2026, 1, 13).in_time_zone.change(hour: 12)

      get_comparison cars_savings_path(timeframe: '2026-01')

      expect(response.body).to include('Without logging in, today and yesterday are left out for data protection.', 'No distance to compare')

      login_as_admin
      get_comparison cars_savings_path(timeframe: '2026-01')

      expect(response.body).not_to include('Without logging in, today and yesterday are left out for data protection.', 'No distance to compare')
    end

    it 'warns of a gap without a link' do
      get_comparison cars_savings_path(timeframe: '2026')

      expect(warnings).to include(a_string_starting_with('No payments are recorded'))
      expect(response.parsed_body.css('[role="status"] a')).to be_empty
    end
  end

  context 'with the admin' do
    before { login_as_admin }

    # A month is a meaningful comparison period. A relative timeframe ends
    # before today and goes to its year.
    it 'keeps a month and sends a relative timeframe to its year' do
      get cars_savings_path(timeframe: '2025-06')
      expect(response).to have_http_status(:ok)

      get cars_savings_path(timeframe: 'P30D')
      expect(response).to redirect_to('/cars/savings/2026')
    end

    it 'offers only the months, the years and the whole time in the timeframe select' do
      get cars_savings_path(timeframe: '2026', select: 1), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.parsed_body.css('[id$="-picker-input-button-label"]').pluck('id')).to eq(%w[month-picker-input-button-label year-picker-input-button-label])
      expect(response.parsed_body.css('button[data-value]').pluck('data-value').uniq).to eq(%w[all])
    end

    # The desktop has the savings as a tab beside the lists of the cars
    # The title bar of a phone has the name of the menu instead
    it 'shows the savings as the current tab beside the charging sessions' do
      get cars_savings_path(timeframe: '2026')

      tabs = response.parsed_body.css('nav[aria-label="Tabs"] a')
      expect(tabs.pluck('href')).to eq(%w[/cars/charging_sessions/2026 /cars/savings/2026])
      expect(tabs.last['aria-current']).to eq('location')
      expect(response.parsed_body.at_css('title').text).to include('EV vs. combustion car')
    end

    # A shorter timeframe goes to its year, and the selection of the guest
    # charges has no car to compare
    it 'links the tab of the charging sessions to the savings of the year, without the guest' do
      start = Date.new(2026, 1, 14).in_time_zone.change(hour: 12)
      ChargingSession.create!(kind: :wallbox, origin: :detection, guest: true, started_at: start, ended_at: start + 1.hour, kwh: 5)

      get cars_charging_sessions_path(kind: 'wallbox', timeframe: '2026-W03', car: 'guest')

      expect(response).to have_http_status(:ok)

      expect(response.parsed_body.css('nav[aria-label="Tabs"] a').pluck('href')).to include('/cars/savings/2026')
    end

    # The comparison takes the time, so the page comes without it first
    it 'shows the page with a frame that asks the same address for the comparison' do
      get cars_savings_path(timeframe: '2026')

      frame = response.parsed_body.at_css('turbo-frame#comparison')
      expect(frame['src']).to eq('/cars/savings/2026')
      expect(frame['target']).to eq('_top')
      expect(chart_data).to be_nil

      get_comparison cars_savings_path(timeframe: '2026')

      expect(response.parsed_body.at_css('turbo-frame#comparison')).to be_present
    end

    it 'asks for a combustion car without one' do
      get_comparison cars_savings_path

      expect(response.body).to include('No combustion car set')
    end

    # Without fuel prices, there is no comparison
    context 'without fuel prices' do
      let(:fuel_prices) { instance_double(Car::FuelPrices, any?: false) }

      it 'leads to the car page' do
        get cars_savings_path

        expect(response).to redirect_to(cars_home_path)
      end

      it 'has no tab beside the charging sessions' do
        get cars_charging_sessions_path(timeframe: '2026')

        expect(hrefs).not_to include(a_string_starting_with('/cars/savings'))
      end
    end

    context 'with a combustion car' do
      before { car.update!(active_from: Date.new(2025, 1, 1), fuel_type: 'petrol', fuel_consumption: 8, combustion_tax: 365) }

      it 'shows a comparison for a month' do
        get_comparison cars_savings_path(timeframe: '2026-01', car: car.id)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.at_css('[data-controller="car--comparison-page--component"]')).to be_present
      end

      # 150 km at 8 l/100 km and 2 EUR/l, and 365 EUR tax for the year, of
      # which 2026 has 266 days up to today. The prices of the year range
      # from 1.90 to 2.10 EUR/l.
      it 'shows the savings, the calculation of each column and the months' do
        get_comparison cars_savings_path(timeframe: '2026')

        expect(response.parsed_body.text.squish).to include('Without PV, it would be', 'Per 100 km190.26 €')
        expect(rows).to include('Consumption per 100 km 8.0 liters', '× Distance 150 km', '= Fuel 12 liters', 'Price per liter 1.90 – 2.10 €', '= Fuel cost 24 €', '+ Vehicle tax 266 €', '= Running costs 290 €', 'Per 100 km 193.33 €')

        # 30 kWh for 150 km, 10 kWh of them from the grid for 3.00 EUR, and
        # the PV energy for the rest of 4.60 EUR
        expect(rows).to include('Consumption per 100 km 20.0 kWh', '= Energy 30 kWh', 'PV energy 2 €', '+ Grid energy 3 €', '= Electricity cost 5 €', 'Per 100 km 3.07 €')
      end

      # 24 EUR fuel for 150 km. The car has no other costs, so its electricity
      # cost is its total, and only the total has a row per 100 km.
      it 'shows the energy cost per 100 km below the energy cost, if other costs add to it' do
        get_comparison cars_savings_path(timeframe: '2026')

        expect(rows.each_cons(2)).to include(['= Fuel cost 24 €', 'Per 100 km 16.00 €'])
        expect(rows.count('Per 100 km 3.07 €')).to eq(1)
      end

      describe 'the details of the calculation' do
        def details = response.parsed_body.at_css('[data-controller="car--comparison-page--component"]')

        def row(text) = table_rows.find { row_text(it) == text }

        it 'hides them without the cookie, so each column starts with its energy cost' do
          get_comparison cars_savings_path(timeframe: '2026')

          expect(details['data-expanded']).to be_nil
          expect(details.at_css('button')['aria-expanded']).to eq('false')
          expect(row('× Distance 150 km')['class']).to include('hidden')
          expect(row('= Fuel cost 24 €')['class']).not_to include('hidden')
        end

        it 'shows them with the cookie' do
          cookies[Car::ComparisonPage::Component::COOKIE] = 'true'

          get_comparison cars_savings_path(timeframe: '2026')

          expect(details['data-expanded']).not_to be_nil
          expect(details.at_css('button')['aria-expanded']).to eq('true')
        end

        # 730 EUR of insurance and 365 EUR of GHG quota are 532 EUR and 266 EUR
        # for the 266 days of 2026 up to today. The row links to all payments of the comparison.
        it 'puts the payments of the car in one row without them' do
          car.payments.create!(category: :insurance, date: Date.new(2026, 4, 20), amount: 730)
          car.payments.create!(category: :ghg_quota, date: Date.new(2026, 4, 20), amount: 365)

          get_comparison cars_savings_path(timeframe: '2026')

          summary = table_rows(summary: true).map { row_text(it) }
          expect(summary.first(2)).to eq(['+ Other costs less GHG quota 266 €'] * 2)
          expect(rows).to include('+ Insurance 532 €', '− GHG quota 266 €')
          expect(response.parsed_body.css('a').pluck('href')).to include(
            "/settings/car_payments?#{{ car: car.id, category: Car::Payment::COMPARED, from: '2026-01-01', to: '2026-12-31' }.to_query}",
          )
        end

        it 'keeps a single payment of the car in one row without them' do
          car.payments.create!(category: :ghg_quota, date: Date.new(2026, 4, 20), amount: 365)

          get_comparison cars_savings_path(timeframe: '2026')

          expect(table_rows(summary: true).map { row_text(it) }.first(2)).to eq(['− GHG quota 266 €'] * 2)
        end
      end

      it 'names the data that the comparison includes in the tooltip of the savings' do
        get_comparison cars_savings_path(timeframe: '2026')

        expect(response.body).to include('Data included:', '<li>Distance driven by the car</li>')
      end

      describe 'the warnings' do
        def warning_links = response.parsed_body.css('[role="status"] a').pluck('href')

        # A proposal is an offsite session without the mark of the user
        it 'warns of the gaps of the data, each with a link for the admin where one fills it' do
          start = Date.new(2026, 1, 15).in_time_zone.change(hour: 10)
          ChargingSession.create!(kind: :offsite, origin: :detection, car:, started_at: start, ended_at: start + 1.hour, kwh: 20, cost: 10)
          ChargingSession.offsite.update_all(assigned_manually: false) # rubocop:disable Rails/SkipsModelValidations

          get_comparison cars_savings_path(timeframe: '2026')

          expect(warnings).to include(
            a_string_starting_with('One offsite charging session is not confirmed yet'),
            a_string_starting_with('No payments are recorded'),
          )
          expect(warnings).not_to include(a_string_starting_with('Without the power splitter'))
          expect(warning_links).to eq([cars_charging_sessions_path(kind: 'offsite', car: nil, timeframe: '2026', review: '1'), settings_car_payments_path])
        end

        # 80 km in June 2026, far from the charge of January
        it 'warns of the distance without a cost' do
          summary(Date.new(2026, 6, 10), :car_odometer_1, :sum, 80)

          get_comparison cars_savings_path(timeframe: '2026')

          expect(warnings).to include(a_string_starting_with('80 km lack charging data or a fuel price'))
        end

        it 'warns of a wallbox without the power splitter' do
          allow(Sensor::Config).to receive(:exists?).and_call_original
          allow(Sensor::Config).to receive(:exists?).with(:wallbox_power_grid, check_policy: false).and_return(false)

          get_comparison cars_savings_path(timeframe: '2026')

          expect(warnings).to include(a_string_starting_with('Without the power splitter'))
        end

        it 'warns of a combustion car without a tax, with a link to its settings' do
          car.update!(combustion_tax: nil)

          get_comparison cars_savings_path(timeframe: '2026')

          expect(warnings).to include(a_string_starting_with('The combustion car has no vehicle tax'))
          expect(warning_links).to include(edit_settings_car_path(car))
        end

        it 'does not warn of the payments with a payment' do
          car.payments.create!(category: :insurance, date: Date.new(2026, 4, 20), amount: 365)

          get_comparison cars_savings_path(timeframe: '2026')

          expect(warnings).not_to include(a_string_starting_with('No payments are recorded'))
        end

        it 'warns of the payments with a payment in another year only' do
          car.payments.create!(category: :insurance, date: Date.new(2025, 4, 20), amount: 365)

          get_comparison cars_savings_path(timeframe: '2026')

          expect(warnings).to include(a_string_starting_with('No payments are recorded'))
        end
      end

      it 'shows the years of the whole time as a chart with a title, each with a path to its comparison' do
        get_comparison cars_savings_path

        expect(chart_data).to include('labels' => %w[2025 2026], 'paths' => %w[/cars/savings/2025 /cars/savings/2026])
        expect(chart_data['titles']).to eq(['2025 · 0 km', '2026 · 150 km'])
        expect(chart_title).to eq('Running costs per year')
      end

      # 2026 holds today. A car that came on 2025-03-01 drove on a part of
      # 2025 alone.
      it 'marks the years with fewer days' do
        get_comparison cars_savings_path

        expect(chart_data['partial']).to eq([false, true])

        car.update!(active_from: Date.new(2025, 3, 1))
        get_comparison cars_savings_path

        expect(chart_data['partial']).to eq([true, true])
      end

      it 'shows the months of a year with a title and a path to each month' do
        get_comparison cars_savings_path(timeframe: '2026')

        expect(chart_data).to include('labels' => %w[Jan Feb Mar Apr May Jun Jul Aug Sep])
        expect(chart_data['paths']).to eq((1..9).map { format('/cars/savings/2026-%02d', it) })
        expect(chart_title).to eq('Running costs per month')
      end

      # 150 km on 2026-01-12 and 50 km on 2026-01-21, with the same rates.
      # The fuel costs 2.00 EUR per liter.
      it 'shows the electricity and the fuel cost of each week with a distance per 100 km' do
        summary(Date.new(2026, 1, 21), :car_odometer_1, :sum, 50)

        get_comparison cars_savings_path(timeframe: '2026')

        data = chart_data('comparison-rate-chart')
        expect(data['weeks']).to eq(
          [
            { 'from' => '2026-01-12', 'to' => '2026-01-18', 'distance' => '150 km' },
            { 'from' => '2026-01-19', 'to' => '2026-01-25', 'distance' => '50 km' },
          ],
        )
        # The weeks share the months of the chart of the periods above: a
        # week starts on the 12th and on the 19th of January
        expect(data['labels']).to eq(chart_data['labels'])
        expect(data['positions']).to eq([(11 / 31.0).round(4), (18 / 31.0).round(4)])
        car_series, combustion_series = data['series']
        expect(car_series['label']).to eq('EV')
        expect(combustion_series['label']).to eq('Combustion car')
        expect(combustion_series['values']).to all(eq((car.fuel_consumption * 2).round(2)))
      end

      # 365 EUR for 2026 are 266 EUR for its days up to today. The link opens
      # the GHG quota of the year, which shows the whole income.
      it 'takes the part of the GHG quota from the cost of the car in a row of its own and links it to its payments' do
        car.payments.create!(category: :ghg_quota, date: Date.new(2026, 4, 20), amount: 365, note: 'Quota of 2026')

        get_comparison cars_savings_path(timeframe: '2026')

        expect(rows).to include('− GHG quota 266 €')
        expect(rows.join).not_to include('Other costs')
        expect(response.parsed_body.css('a').pluck('href')).to include(
          "/settings/car_payments?#{{ car: car.id, category: %w[ghg_quota], from: '2026-01-01', to: '2026-12-31' }.to_query}",
        )
        expect(response.body).not_to include('Quota of 2026')
      end

      # 365 EUR of insurance and 365 EUR of GHG quota are 266 EUR each for
      # 2026 up to today. Each category has a row of its own in the order of the
      # form, and links to its payments. The combustion car has the
      # insurance, but no GHG quota.
      it 'shows each category of the payments in a row of its own' do
        car.payments.create!(category: :insurance, date: Date.new(2026, 4, 20), amount: 365)
        car.payments.create!(category: :ghg_quota, date: Date.new(2026, 4, 20), amount: 365)

        get_comparison cars_savings_path(timeframe: '2026')

        expect(rows.select { it.start_with?('+ Insurance', '− GHG quota') }).to eq(['+ Insurance 266 €', '− GHG quota 266 €', '+ Insurance 266 €', '− GHG quota 266 €', '+ Insurance 266 €'])
        expect(response.parsed_body.css('a').pluck('href')).to include(
          "/settings/car_payments?#{{ car: car.id, category: %w[insurance], from: '2026-01-01', to: '2026-12-31' }.to_query}",
        )
      end

      # 365 EUR for 2026 are 266 EUR for its days up to today, for the
      # combustion car too. The tax of the combustion car of 266 EUR stands in the row of the
      # vehicle tax. Without the details, one row holds both. It has no
      # link, because the payments do not hold the tax. A tooltip gives the
      # two parts instead. An expense is not red.
      it 'adds the other costs to both cars, with the tax of the combustion car' do
        car.payments.create!(category: :insurance, date: Date.new(2026, 4, 20), amount: 365)

        get_comparison cars_savings_path(timeframe: '2026')

        tooltip = response.parsed_body.css('td [data-tooltip-target="html"]').each(&:remove).first
        expect(tooltip.css('span').map { it.text.squish }).to eq(['Insurance, maintenance and more', '€ 266', 'Vehicle tax (€ 365 per year)', '€ 266'])
        expect(table_rows(summary: true).map { row_text(it) }.grep(/\A/)).to eq(['+ Insurance 266 €', '+ Insurance 266 €', '+ Other costs 532 €'])
        expect(rows).to include('+ Vehicle tax 266 €', '= Running costs 556 €')
        expect(rows.count('+ Insurance 266 €')).to eq(3)
        expect(table_rows.flat_map { it.css('a').pluck('href') }.grep(%r{\A/settings/car_payments})).to have_attributes(size: 3)
      end

      # The tax of 2025 counts, but the car drove in 2026 alone. 2026 has 266
      # days of tax and of the income up to today. The car costs 4.60 EUR -
      # 266 EUR, the combustion car 24 EUR + 266 EUR.
      it 'gives the cost of each column for each year' do
        car.payments.create!(category: :ghg_quota, date: Date.new(2026, 1, 20), amount: 365)

        get_comparison cars_savings_path

        car_series, without_pv_series, combustion_series = chart_data['series']
        expect(car_series).to eq('label' => 'EV (with PV system)', 'values' => [0, -261])
        expect(without_pv_series['values'].map(&:round)).to eq([0, -258])
        expect(combustion_series).to eq('label' => 'Combustion car', 'values' => [365, 290])
      end

      # The whole time holds the whole income of 2025
      it 'links each number to the place it comes from' do
        car.payments.create!(category: :ghg_quota, date: Date.new(2025, 6, 1), amount: 100)

        get_comparison cars_savings_path

        expect(response.parsed_body.css('turbo-frame a').pluck('href')).to include(
          '/cars/car_distance/all',
          '/cars/car_consumption_rate/all',
          '/cars/car_driving_costs/all',
          "/settings/cars/#{car.id}/edit",
        )
        expect(response.parsed_body.css('turbo-frame a').pluck('href')).to include(start_with('/settings/car_payments?'))
      end

      it 'links no title' do
        get_comparison cars_savings_path

        expect(response.parsed_body.css('a').map { it.text.squish }).not_to include('EV (with PV system)', 'Combustion car')
      end

      # A second trip on a day without a fuel price: the car page shows its
      # distance and its cost, but the comparison leaves them out
      context 'with a day that the comparison leaves out' do
        before do
          summary(Date.new(2026, 1, 13), :car_odometer_1, :sum, 50)
          allow(fuel_prices).to receive(:at) { |date| 2.0 unless date == Date.new(2026, 1, 13) }
        end

        it 'links no number that the car page shows otherwise' do
          get_comparison cars_savings_path(timeframe: '2026')

          expect(response.parsed_body.css('turbo-frame a').pluck('href')).not_to include('/cars/car_distance/2026', '/cars/car_driving_costs/2026', '/cars/car_cost_rate/2026')
        end
      end

      # 80 km in June 2025, far from the charge of January 2026
      it 'says that a year without a distance with a cost has nothing to compare' do
        summary(Date.new(2025, 6, 10), :car_odometer_1, :sum, 80)

        get_comparison cars_savings_path(timeframe: '2025')

        expect(response.parsed_body.text.squish).to include('No distance to compare')
      end

      # A comparison of the first car alone would leave out the distance of
      # the second
      context 'with a second car without a combustion car' do
        before do
          Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_2' => 'Wartburg:odometer'))
          Car.create!(id: 2, name: 'Wartburg', active_from: Date.new(2025, 1, 1))
        end

        after { Sensor::Config.setup(ENV) }

        it 'asks for a combustion car of each car for all cars' do
          get_comparison cars_savings_path(timeframe: '2026')

          expect(response.parsed_body.text.squish).to include('No combustion car set', 'in the settings of each car')
        end

        it 'compares the first car alone' do
          get_comparison cars_savings_path(timeframe: '2026', car: car.id)

          expect(warnings).not_to include(a_string_including('lack charging data'))
          expect(response.body).not_to include('No combustion car set')
        end
      end

      # The prices of another fuel make the comparison available
      context 'without prices of its fuel' do
        let(:fuel_prices) { instance_double(Car::FuelPrices, any?: false, at: nil) }

        before { allow(Car::FuelPrices).to receive(:new).with('diesel').and_return(instance_double(Car::FuelPrices, any?: true)) }

        it 'says that the fuel prices are missing' do
          get_comparison cars_savings_path

          expect(response.body).to include('No fuel prices yet')
        end
      end
    end
  end
end
