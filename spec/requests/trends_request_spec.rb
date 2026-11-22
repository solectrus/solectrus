describe 'Trends' do
  subject(:page) { Capybara.string(response.body) }

  before do
    travel_to Date.new(2026, 3, 1)

    create_summary(
      date: Date.new(2025, 1, 1),
      values: [
        [:inverter_power, :sum, 10_000],
        [:grid_import_power, :sum, 2_000],
        [:grid_export_power, :sum, 5_000],
      ],
    )
    create_summary(
      date: Date.new(2026, 1, 1),
      values: [
        [:inverter_power, :sum, 12_000],
        [:grid_import_power, :sum, 3_200],
        [:grid_export_power, :sum, 4_000],
      ],
    )
  end

  def get_trends(timeframe: '2026-01', frame: 'modal', referer: 'http://www.example.com/2026-01', **params)
    get trends_path(timeframe:, **params), headers: { 'Turbo-Frame' => frame, 'Referer' => referer }.compact
  end

  # The row of a sensor by its name: a name can begin another one
  def row(name) = page.all('.trend-overview-row').find { it.find('.trend-overview-name').text == name }

  context 'with the permission' do
    before { stub_feature(:trends, :power_splitter) }

    it 'shows the change of each sensor of the page' do
      get_trends

      expect(response).to have_http_status(:ok)
      expect(page).to have_css('h2', text: 'Trends Jan 2026')
      expect(page).to have_css('p', text: 'compared with Jan 2025')
      expect(row('Grid import').find('.trend-overview-value').text).to eq('+60 %')
      expect(row('Generation').find('.trend-overview-value').text).to eq('+20 %')
    end

    it 'leads from a part of the grid to its own insights' do
      get_trends

      link = row('Grid import')
      expect(link[:href]).to eq('/insights/grid_import_power/2026-01')
      expect(link['data-nav-title']).to eq('Grid import')
    end

    it 'offers the month before as the earlier period' do
      get_trends(base: 'previous_period')

      expect(page).to have_link('Previous month', href: '/trends/2026-01?base=previous_period')
      expect(page).to have_css('[aria-current="page"]', text: 'Previous month')
      expect(row('Grid import')[:href]).to eq('/insights/grid_import_power/2026-01?base=previous_period')
    end

    it 'has no choice of the earlier period for a year' do
      get_trends(timeframe: '2025')

      expect(page).to have_no_link('Previous month')
    end

    it 'shows the sensors of the page that holds the frame' do
      create_summary(date: Date.new(2026, 1, 2), values: [[:heatpump_power, :sum, 1_000]])
      get_trends(referer: 'http://www.example.com/heatpump/heatpump_power/2026-01')

      expect(page).to have_css('.trend-overview-row', text: 'Power consumption')
      expect(page).to have_no_css('.trend-overview-row', text: 'Grid import')
    end

    # The car page groups by its columns, and each link keeps the car
    it 'shows the charts of the car page' do
      stub_feature(:trends, :car)
      get_trends(referer: 'http://www.example.com/cars/1/2026-01', car: '1')

      expect(page).to have_no_css('.trend-overview-header')
      expect(row('Charged energy')[:href]).to eq('/insights/car_charging/2026-01?car=1')
    end

    it 'sends a request without the frame back to the page' do
      get_trends(frame: nil)

      expect(response).to redirect_to('http://www.example.com/2026-01')
    end

    it 'sends a week back to the page' do
      get_trends(timeframe: '2026-W02')

      expect(response).to redirect_to('http://www.example.com/2026-01')
    end

    describe 'the insights below the overview' do
      def get_insights(sensor_name: 'inverter_power', **params)
        get insights_path(sensor_name:, timeframe: '2026-01', **params),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026-01' }
      end

      it 'leads back to the overview' do
        get_insights(base: 'previous_period')

        expect(page).to have_css('header[data-sheet-depth="1"]')
        expect(page).to have_link('Trends Jan 2026', href: '/trends/2026-01?base=previous_period')
      end

      it 'compares the value with the earlier period' do
        get_insights

        expect(page).to have_css('.insights-row', text: /Jan 2026\s*12\.0 kWh/)
        expect(page).to have_css('.insights-row', text: /Jan 2025\s*10\.0 kWh/)
        expect(page).to have_css('.insights-comparison-diff.text-signal-positive', text: '+2.0 kWh')
      end

      # The page of the same days a year before, out of the sheet
      it 'leads from the earlier period to its page' do
        get_insights

        expect(page).to have_css('a.insights-row[data-turbo-frame="_top"][href="/inverter_power/2025-01"]', text: 'Jan 2025')
      end

      it 'leads from the days of a running year before to their page' do
        stub_feature(:trends, :heatpump)
        create_summary(date: Date.new(2025, 1, 1), values: [[:outdoor_temp, :avg, 2.0], [:heatpump_heating_power, :sum, 20_000]])
        get insights_path(sensor_name: 'outdoor_temp', timeframe: '2026'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/heatpump/2026' }

        expect(page).to have_link(href: '/heatpump/outdoor_temp/2025-01-01..2025-02-28', class: 'insights-row')
      end

      # The change of the values as they read, not "+0 kWh"
      it 'shows the change of the rounded values' do
        create_summary(date: Date.new(2025, 1, 1), values: [[:inverter_power, :sum, 10_740]])
        create_summary(date: Date.new(2026, 1, 1), values: [[:inverter_power, :sum, 10_760]])
        get_insights

        expect(page).to have_css('.insights-row', text: /Jan 2026\s*10\.8 kWh/)
        expect(page).to have_css('.insights-comparison-diff', text: '+0.1 kWh')
      end

      # A warm day without heat counts not at all
      it 'compares the outdoor temperature of the days with heat' do
        stub_feature(:trends, :heatpump)
        create_summary(date: Date.new(2025, 1, 1), values: [[:outdoor_temp, :avg, 2.0], [:heatpump_heating_power, :sum, 20_000]])
        create_summary(date: Date.new(2026, 1, 1), values: [[:outdoor_temp, :avg, 3.0], [:heatpump_heating_power, :sum, 20_000]])
        create_summary(date: Date.new(2026, 1, 2), values: [[:outdoor_temp, :avg, 15.0], [:heatpump_heating_power, :sum, 0]])
        get insights_path(sensor_name: 'outdoor_temp', timeframe: '2026-01'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/heatpump/2026-01' }

        expect(page).to have_css('header', text: 'Outdoor temperature while heating')
        expect(page).to have_css('.insights-row', text: /Jan 2026\s*3\.0\s*°C/)
        expect(page).to have_css('.insights-comparison-diff', text: '+1.0 °C')
      end

      # In summer, the hot water weighs each day about the same, so a month or
      # a day of the weighted temperature shows the plain weather
      it 'shows the outdoor temperature of a year without its months and days' do
        stub_feature(:trends, :heatpump)
        create_summary(date: Date.new(2025, 1, 1), values: [[:outdoor_temp, :avg, 2.0], [:outdoor_temp, :min, -1.0], [:outdoor_temp, :max, 5.0], [:heatpump_heating_power, :sum, 20_000]])
        create_summary(date: Date.new(2026, 1, 1), values: [[:outdoor_temp, :avg, 3.0], [:outdoor_temp, :min, 0.0], [:outdoor_temp, :max, 6.0], [:heatpump_heating_power, :sum, 20_000]])
        get insights_path(sensor_name: 'outdoor_temp', timeframe: '2026'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/heatpump/2026' }

        expect(page).to have_css('.insights-comparison-diff', text: '+1.0 °C')
        expect(page).to have_no_css('.insights-months, .insights-subpage')
        expect(page).to have_no_text('Maximum')
      end

      it 'compares with the month before' do
        get_insights(base: 'previous_period')

        expect(page).to have_css('.insights-row', text: 'Dec 2025')
      end

      # The tooltip of the segment shows the costs already
      it 'compares a part of the grid without its costs' do
        get_insights(sensor_name: 'grid_import_power')

        expect(page).to have_css('.insights-row', text: /Jan 2025\s*2\.0 kWh/)
        expect(page).to have_no_css('.insights-row', text: 'Costs')
      end

      it 'shows the change of each month of a year' do
        get insights_path(sensor_name: 'inverter_power', timeframe: '2026'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026' }

        expect(page).to have_css('.insights-month', text: /Jan\s*\+2\.0 kWh/)
        expect(page).to have_css('.insights-month .trend-overview-bar.bg-signal-positive')
      end

      # The tooltip of a month names both values behind its change
      it 'shows the values of a month in its tooltip' do
        get insights_path(sensor_name: 'inverter_power', timeframe: '2026'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026' }

        expect(page).to have_css('.insights-month [data-tooltip-target="html"]', text: /Jan 2026: 12\.0 kWh\s*Jan 2025: 10\.0 kWh/, visible: :all)
      end

      # The months read with the decimals of the largest change, and a month
      # without a change shows a zero with its unit
      it 'shows a month without a change with its unit' do
        [Date.new(2025, 2, 1), Date.new(2026, 2, 1)].each do |date|
          create_summary(date:, values: [[:inverter_power, :sum, 5_000]])
        end
        get insights_path(sensor_name: 'inverter_power', timeframe: '2026'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026' }

        expect(page).to have_css('.insights-month', text: /Feb\s*±0 kWh/)
        expect(page).to have_css('.insights-month .trend-overview-dot')
      end

      # Beside a change of 400 kWh, the months have no decimals, so a change
      # of 0.3 kWh reads as none
      it 'shows a small change of a month as none' do
        create_summary(date: Date.new(2026, 1, 1), values: [[:inverter_power, :sum, 10_300]])
        create_summary(date: Date.new(2025, 2, 1), values: [[:inverter_power, :sum, 100_000]])
        create_summary(date: Date.new(2026, 2, 1), values: [[:inverter_power, :sum, 500_000]])
        get insights_path(sensor_name: 'inverter_power', timeframe: '2026'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026' }

        expect(page).to have_css('.insights-month', text: /Jan\s*±0 kWh/)
        expect(page).to have_css('.insights-month .insights-month-value.text-muted', text: '±0 kWh')
        expect(page).to have_css('.insights-month', text: /Feb\s*\+400 kWh/)
      end

      # The overview shows no change, as the year before has data from June
      # on only, so the insights compare neither
      it 'does not compare with a year that begins before the data' do
        create_summary(date: Date.new(2025, 6, 1), values: [[:house_power, :sum, 1_000]])
        create_summary(date: Date.new(2026, 1, 2), values: [[:house_power, :sum, 3_000]])
        get insights_path(sensor_name: 'house_power', timeframe: '2026'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026' }

        expect(page).to have_css('div.insights-row', text: /2025\s*–/)
        expect(page).to have_no_css('.insights-comparison-diff')
        expect(page).to have_no_css('.insights-month')
      end

      # A month of the first year of a sensor has no value a year before
      it 'shows a month without a value of the year before' do
        create_summary(date: Date.new(2026, 2, 1), values: [[:inverter_power, :sum, 5_000]])
        get insights_path(sensor_name: 'inverter_power', timeframe: '2026'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026' }

        expect(page).to have_css('.insights-month', text: /Feb\s*–/)
        expect(page).to have_css('.insights-month .trend-overview-track.is-empty')
      end

      it 'shows no months for a month' do
        get_insights

        expect(page).to have_no_css('.insights-month')
      end

      # The running month compares with the same days of the year before
      it 'compares the days of the battery in a running month' do
        travel_to Date.new(2026, 3, 15)
        [Date.new(2025, 3, 1), Date.new(2026, 3, 2)].each do |date|
          create_summary(date:, values: [[:battery_soc, :avg, 50], [:battery_soc, :min, 0], [:battery_soc, :max, 100]])
        end
        get insights_path(sensor_name: 'battery_soc', timeframe: '2026-03'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026-03' }

        expect(page).to have_css('.insights-row', text: /Mar 1–14, 2026\s*50 %/)
        expect(page).to have_css('.insights-row', text: /Full\s*Previous year: 1 day\s*1 day/)
        expect(page).to have_css('.insights-row', text: /Charged consecutively\s*Previous year: 0 days\s*0 days/)
      end

      # 50.4 % and 50.6 % read 50 % and 51 %, so the change reads one point
      it 'shows the change of a percentage and of the days as they read' do
        travel_to Date.new(2026, 3, 15)
        create_summary(date: Date.new(2025, 3, 1), values: [[:battery_soc, :avg, 50.4], [:battery_soc, :min, 0], [:battery_soc, :max, 100]])
        [Date.new(2026, 3, 2), Date.new(2026, 3, 3)].each do |date|
          create_summary(date:, values: [[:battery_soc, :avg, 50.6], [:battery_soc, :min, 0], [:battery_soc, :max, 100]])
        end
        get insights_path(sensor_name: 'battery_soc', timeframe: '2026-03'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/2026-03' }

        expect(page).to have_css('.insights-comparison-diff', text: '+1 pp')
        expect(page).to have_css('.insights-row', text: /Full\s*Previous year: 1 day\s*2 days\s*\+1 day/)
      end

      it 'compares a chart of the car page with the report of its cars' do
        stub_feature(:trends, :car)
        Car.create!(id: 1, active_from: Date.new(2025, 1, 1))
        [Time.zone.local(2025, 1, 10, 12), Time.zone.local(2026, 1, 10, 12)].each_with_index do |start, index|
          ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: start, ended_at: start + 1.hour, kwh: (index + 1) * 10, car_id: 1)
        end
        get insights_path(sensor_name: 'car_charging', timeframe: '2026-01', car: '1'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/cars/1/2026-01' }

        expect(page).to have_css('.insights-row', text: /Jan 2026\s*20\.0 kWh/)
        expect(page).to have_css('.insights-row', text: /Jan 2025\s*10\.0 kWh/)
        expect(page).to have_link(href: %r{/cars/1/2026-01-10}, text: /Maximum.*20\.0 kWh/)
      end

      it 'shows the change of each month of a chart of the car page' do
        stub_feature(:trends, :car)
        Car.create!(id: 1, active_from: Date.new(2025, 1, 1))
        [Time.zone.local(2025, 1, 10, 12), Time.zone.local(2026, 1, 10, 12)].each_with_index do |start, index|
          ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: start, ended_at: start + 1.hour, kwh: (index + 1) * 10, car_id: 1)
        end
        get insights_path(sensor_name: 'car_charging', timeframe: '2026', car: '1'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/cars/1/2026' }

        expect(page).to have_css('.insights-month', text: /Jan\s*\+10\.0 kWh/)
      end
    end
  end

  context 'with the whole time' do
    before do
      stub_feature(:trends, :power_splitter)
      create_summary(date: Date.new(2024, 1, 1), values: [[:inverter_power, :sum, 9_000]])
    end

    it 'shows the years of each sensor of the page and its best year' do
      get_trends(timeframe: 'all', referer: 'http://www.example.com/all')

      expect(page).to have_css('h2', text: 'Years compared')
      expect(page).to have_no_link('Previous month')
      expect(row('Generation').find('.sr-only').text).to eq('Best year 2025')
      expect(row('Generation')[:href]).to eq('/insights/inverter_power/all')
    end

    describe 'the car page' do
      before do
        stub_feature(:trends, :car)
        Car.create!(id: 1, active_from: Date.new(2025, 1, 1))
        start = Time.zone.local(2025, 7, 1, 12)
        ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: start, ended_at: start + 1.hour, kwh: 20, car_id: 1)
      end

      it 'shows the years of the charts of the selected car' do
        get_trends(timeframe: 'all', referer: 'http://www.example.com/cars/1/all', car: '1')

        expect(page).to have_no_css('.trend-overview-header')
        expect(row('Charged energy')[:href]).to eq('/insights/car_charging/all?car=1')
      end

      it 'shows the calendar and the highest day below the overview' do
        get insights_path(sensor_name: 'car_charging', timeframe: 'all', car: '1'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/cars/1/all' }

        expect(page).to have_link(href: '/trends/all?car=1')
        expect(page).to have_css('.insights-subpage a[data-turbo-frame="_top"][href="/cars/1/car_charging/2025-07"]')
        expect(page).to have_css('a[data-turbo-frame="_top"][href="/cars/1/2025-07-01"]', text: /Maximum/)
      end

      # A month before the first day of use has no value, not a zero
      it 'shows no month before the first day of use in the calendar' do
        Car.find(1).update!(active_from: Date.new(2025, 6, 15))
        get insights_path(sensor_name: 'car_charging', timeframe: 'all', car: '1'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/cars/1/all' }

        expect(page).to have_css('.insights-subpage a[href="/cars/1/car_charging/2025-06"]')
        expect(page).to have_no_css('.insights-subpage a[href="/cars/1/car_charging/2025-05"]')
      end
    end

    describe 'the insights below the overview' do
      before do
        get insights_path(sensor_name: 'inverter_power', timeframe: 'all'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/all' }
      end

      it 'leads back to the overview' do
        expect(page).to have_css('header[data-sheet-depth="1"]')
        expect(page).to have_link(href: '/trends/all')
      end

      it 'names the heat pump by its electricity on its own page, also on the way back from the calendar' do
        create_summary(date: Date.new(2025, 6, 1), values: [[:heatpump_power, :sum, 1_000]])
        get insights_path(sensor_name: 'heatpump_power', timeframe: 'all'),
            headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/heatpump/heatpump_power/all' }

        expect(page).to have_css('h2', text: 'Power consumption')
        expect(page).to have_css('.insights-back', text: 'Power consumption')
      end

      it 'shows the calendar and the days, not what the page shows' do
        expect(page).to have_css('.insights-subpage a[data-turbo-frame="_top"][href="/inverter_power/2026-01"]')
        expect(page).to have_link(href: '/inverter_power/2026-01-01', text: /Maximum/)
        expect(page).to have_css('a[data-turbo-frame="_top"]', text: /Maximum/)
        expect(page).to have_no_css('.insights-heading')
        expect(page).to have_no_css('.insights-comparison-row')
      end
    end

    # The total consumption has no summary of its own, so its highest day
    # adds up the consumers of each day
    it 'finds the highest day of the total consumption' do
      create_summary(date: Date.new(2025, 6, 1), values: [[:house_power, :sum, 4_000], [:wallbox_power, :sum, 3_000]])
      create_summary(date: Date.new(2025, 6, 2), values: [[:house_power, :sum, 5_000], [:wallbox_power, :sum, 0]])
      get insights_path(sensor_name: 'total_consumption', timeframe: 'all'),
          headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/all' }

      expect(page).to have_link(href: '/total_consumption/2025-06-01', text: /Maximum.*7\.0 kWh/)
    end

    # The battery has the calendar of its charge, a color of its own for each
    # value, and the longest run of days without an empty battery
    it 'shows the days of the battery for the whole time' do
      (3..5).each do |day|
        create_summary(date: Date.new(2025, 10, day), values: [[:battery_soc, :avg, 60], [:battery_soc, :min, 10], [:battery_soc, :max, 100]])
      end
      get insights_path(sensor_name: 'battery_soc', timeframe: 'all'),
          headers: { 'Turbo-Frame' => 'sheet-page', 'Referer' => 'http://www.example.com/all' }

      expect(page).to have_css('.insights-subpage a[href="/battery_soc/2025-10"]')
      expect(page).to have_link(href: '/battery_soc/2025-10-03..2025-10-05', text: /Charged consecutively/)
    end
  end

  context 'without the permission' do
    before { stub_feature }

    it 'shows a teaser in place of the overview' do
      get_trends

      expect(response).to have_http_status(:ok)
      expect(page).to have_css('h2', text: 'Trends Jan 2026')
      expect(page).to have_text('Exclusively for sponsors')
      expect(page).to have_no_css('.trend-overview')
      # The teaser takes the gray of the sheet
      expect(page).to have_no_css('.bg-white')
    end

    # The demo opens the page that the visitor comes from
    it 'links the demo to the same page' do
      get_trends(referer: 'http://www.example.com/inverter_power/2026-01')

      expect(page).to have_link(href: %r{\Ahttps://demo\.solectrus\.de/inverter_power/2026-01\?})
    end

    it 'shows the teaser for the whole time too' do
      get_trends(timeframe: 'all', referer: 'http://www.example.com/all')

      expect(page).to have_css('h2', text: 'Years compared')
      expect(page).to have_no_css('.trend-overview')
    end

    it 'sends a week back to the page' do
      get_trends(timeframe: '2026-W02')

      expect(response).to redirect_to('http://www.example.com/2026-01')
    end
  end
end
