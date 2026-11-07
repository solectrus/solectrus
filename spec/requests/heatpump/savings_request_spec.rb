# The heat pump starts on January 10, 2026, so a payment of 2026 spreads
# over 356 days: 356 EUR is 1 EUR a day.
describe 'Heat pump savings' do
  include_context 'with heat pump comparison'

  let(:prices) { { 'gas' => [[Date.new(2023, 1, 1), 0.10]] } }

  before do
    travel_to Date.new(2026, 1, 20).in_time_zone.change(hour: 12)
    heat_day(Date.new(2026, 1, 10))
    allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
  end

  def texts = response.parsed_body.css('tr').map { it.css('td').map { |cell| cell.text.squish }.compact_blank.join(' ') }

  context 'with a gas heating' do
    before do
      Setting.heatpump_heating_fuel_type = 'gas'
      Setting.heatpump_heating_efficiency = 90
      Setting.heatpump_heating_fixed_costs = 365
    end

    # The price links to the modal of the prices, and the heat pump without
    # PV hides by default
    it 'shows the calculation of the heating on a page with the way back' do
      get heatpump_savings_path(timeframe: '2026-01')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Comparison with gas heating')
      expect(response.parsed_body.css("a[href='#{heatpump_home_path(sensor_name: 'heatpump_heating_power', timeframe: '2026-01')}']")).to be_present
      expect(texts).to include('= Gas needed 10.0 kWh', '× Price 0.100 €/kWh', '= Gas costs 1.00 €', '+ Running costs 1.00 €', '= Costs 2.00 €')
      expect(response.parsed_body.at_css("a[href='#{heatpump_fuel_prices_path(timeframe: '2026-01')}']")['data-turbo-frame']).to eq('modal')
      expect(response.parsed_body.at_css('[data-controller="without-pv-toggle"]')['data-without-pv']).to be_nil
    end

    it 'shows the heat pump without PV with the cookie' do
      cookies[:heatpump_comparison_without_pv] = 'true'

      get heatpump_savings_path(timeframe: '2026-01')

      expect(response.parsed_body.at_css('[data-controller="without-pv-toggle"]')['data-without-pv']).not_to be_nil
    end

    it 'names the days that it leaves out' do
      heat_day(Date.new(2022, 12, 31))

      get heatpump_savings_path(timeframe: '2022-12-31..2026-01-11')

      expect(response.body).to include('One day without costs of the heat pump or without a price is missing')
    end

    context 'with heat in three months' do
      before do
        heat_day(Date.new(2025, 11, 10))
        heat_day(Date.new(2025, 12, 10))
      end

      it 'shows the costs of each month in a chart' do
        get heatpump_savings_path(timeframe: '2025-11-01..2026-01-19')

        chart = response.parsed_body.at_css('[data-controller="car--comparison-chart--component"]')
        data = JSON.parse(chart.at_css('script').text)
        expect(data['series'].pluck('key')).to eq(%w[heatpump without_pv heating])
        expect(data['series'].last['values']).to eq([2.0, 2.0, 2.0])
      end
    end

    # The reversed range matches the route, but is no timeframe
    it 'shows the whole time for an invalid timeframe' do
      get '/heatpump/savings/2026-01-11..2026-01-01'

      expect(response).to have_http_status(:ok)
      expect(texts).to include('= Gas needed 10.0 kWh')
    end

    # The heat pump with and without PV get the payments, the heating keeps
    # its own running costs
    it 'adds the payments to the calculation of the heat pump' do
      Heatpump::Payment.create!(category: :operating_costs, date: Date.new(2026, 1, 1), amount: 356)
      Heatpump::Payment.create!(category: :maintenance, date: Date.new(2026, 1, 1), amount: 712)

      get heatpump_savings_path(timeframe: '2026-01')

      expect(texts).to include('Energy costs 0.42 €', '+ Operating costs 1.00 €', '= Costs 3.42 €', '+ Running costs 1.00 €', '= Costs 2.00 €')
      expect(texts.count('+ Maintenance 2.00 €')).to eq(2)
    end

    # The first payment of the heat pump and the running costs of the heating
    # stand in one row
    it 'aligns the running costs of the columns' do
      Heatpump::Payment.create!(category: :maintenance, date: Date.new(2026, 1, 1), amount: 712)

      get heatpump_savings_path(timeframe: '2026-01')

      heatpump, *, heating = response.parsed_body.css('table').map { |table| table.css('tr').map { it.css('td').map { |cell| cell.text.squish }.compact_blank.join(' ') } }
      expect(heatpump.index('+ Maintenance 2.00 €')).to eq(heating.index('+ Running costs 1.00 €'))
    end

    # The heat pump page shows the same costs, because no day with costs is
    # left out. Only the admin opens the payments.
    it 'links the costs to the heat pump page' do
      Heatpump::Payment.create!(category: :maintenance, date: Date.new(2026, 1, 1), amount: 712)

      get heatpump_savings_path(timeframe: '2026-01')

      expect(response.parsed_body.at_css("a[href='#{heatpump_home_path(sensor_name: 'heatpump_costs', timeframe: '2026-01')}']").text.squish).to eq('0.42 €')
      expect(response.body).not_to include(settings_heatpump_payments_path)
    end

    it 'links the costs only with each day of costs' do
      create_summary(date: Date.new(2026, 1, 11), values: [[:heatpump_power, :sum, 3_000], [:heatpump_power_grid, :sum, 1_000]])

      get heatpump_savings_path(timeframe: '2026-01')

      expect(response.body).not_to include(heatpump_home_path(sensor_name: 'heatpump_costs', timeframe: '2026-01'))
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'links each payment to its category in the years of the comparison' do
        Heatpump::Payment.create!(category: :maintenance, date: Date.new(2026, 1, 1), amount: 712)

        get heatpump_savings_path(timeframe: '2026-01')

        href = settings_heatpump_payments_path(category: ['maintenance'], from: '2026-01-01', to: '2026-12-31')
        expect(response.parsed_body.css("a[href='#{href}']").map { it.text.squish }).to eq(['2.00 €', '2.00 €'])
      end
    end

    it 'shows the running costs of the heating without an amount' do
      Setting.heatpump_heating_fixed_costs = nil

      get heatpump_savings_path(timeframe: '2026-01')

      expect(texts).to include('+ Running costs 0 €', '= Costs 1.00 €')
    end

    context 'with an oil heating' do
      let(:prices) { { 'heating_oil' => [[Date.new(2023, 1, 1), 1.06]] } }

      before { Setting.heatpump_heating_fuel_type = 'heating_oil' }

      # 10 kWh of fuel, 10.6 kWh a liter
      it 'buys liters' do
        get heatpump_savings_path(timeframe: '2026-01')

        expect(texts).to include('= Heating oil needed 0.9 liters', '× Price 1.06 €/l')
      end
    end

    it 'shows the build while many days wait for it' do
      allow(Summary).to receive(:missing_or_stale_days_for).and_return((Date.new(2026, 1, 1)..Date.new(2026, 1, 19)).to_a)

      get heatpump_savings_path(timeframe: '2026-01')

      expect(response.parsed_body.at_css('[data-controller="sequential-frames"]')).to be_present
      expect(response.body).not_to include('Gas costs')
    end

    it 'takes the live view as today' do
      get heatpump_savings_path(timeframe: 'now')

      expect(response).to redirect_to(heatpump_savings_path(timeframe: 'day'))
    end

    describe 'the savings on the heat pump page' do
      before { get heatpump_stats_path(sensor_name: 'heatpump_heating_power', timeframe: '2026-01'), headers: { 'Turbo-Frame' => 'stats' } }

      def links = Nokogiri::HTML5.fragment(response.body.gsub(%r{</?template>}, '')).css("a[href^='#{heatpump_savings_path(timeframe: '2026-01')}']")

      it 'shows a badge beside the costs on the desktop' do
        badge = links.find { it['class'].include?('max-lg:hidden') }

        expect(badge['href']).to eq(heatpump_savings_path(timeframe: '2026-01'))
        expect(badge.text.squish).to include('Savings')
        expect(badge['data-turbo-frame']).to eq('_top')
      end

      # A phone has no room for a third badge, and the costs matter more. It
      # opens the comparison in a sheet, like the savings of a car.
      it 'shows a piggy bank with the amount below the costs on a phone, which opens a sheet' do
        compact = links.find { it['class'].include?('savings-compact') }

        expect(compact['href']).to eq(heatpump_savings_path(timeframe: '2026-01', sheet: 1))
        expect(compact['data-turbo-frame']).to eq('modal')
        expect(compact['class']).to include('lg:hidden')
        expect(compact.at_css('svg.fa-piggy-bank')).to be_present
        expect(compact.text.squish).not_to include('Savings')
        expect(compact['aria-label']).to start_with('Savings ')
        expect(compact.ancestors('.group').first.at_css("a[href*='heatpump_costs']")).to be_present
      end
    end

    # A phone opens the comparison from the heat pump page in a sheet, which
    # keeps the timeframe of the page and has no navigation of its own
    it 'opens the comparison in the sheet of a phone' do
      get heatpump_savings_path(timeframe: '2026-01'), params: { sheet: 1 }, headers: { 'Turbo-Frame' => 'modal' }

      sheet_page = response.parsed_body.at_css('turbo-frame#modal dialog.bottom-sheet turbo-frame#sheet-page')
      expect(sheet_page.at_css('h2').text.squish).to eq('Comparison with gas heating')
      expect(sheet_page.at_css('header p').text.squish).to eq('January 2026')
      expect(sheet_page.at_css('turbo-frame#comparison')['target']).to eq('_top')
      expect(sheet_page.text).to include('Gas costs')
      expect(response.body).not_to include(heatpump_home_path(sensor_name: 'heatpump_heating_power', timeframe: '2026-01'))
    end

    describe 'the modal of the prices' do
      it 'shows the prices of the gas' do
        get heatpump_fuel_prices_path(timeframe: '2026-01')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Gas price', '€ 0.100/kWh', 'Newer months are estimates')
      end

      context 'without heat in the timeframe' do
        it 'has nothing' do
          get heatpump_fuel_prices_path(timeframe: '2025-06')

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  context 'without a heating' do
    before { Setting.heatpump_heating_fuel_type = '' }

    it 'says what is missing' do
      get heatpump_savings_path(timeframe: '2026-01')

      expect(response.body).to include('Comparison not set up yet')
      expect(response.body).not_to include(edit_settings_heatpump_path)
    end

    it 'shows no savings on the heat pump page to a visitor' do
      get heatpump_stats_path(sensor_name: 'heatpump_heating_power', timeframe: '2026-01'), headers: { 'Turbo-Frame' => 'stats' }

      expect(response.body).not_to include(heatpump_savings_path(timeframe: '2026-01'))
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'leads to the settings' do
        get heatpump_savings_path(timeframe: '2026-01')

        expect(response.body).to include(edit_settings_heatpump_path)
      end
    end
  end

  context 'without fuel prices' do
    let(:prices) { {} }

    it 'leads to the heat pump page' do
      get heatpump_savings_path(timeframe: '2026-01')

      expect(response).to redirect_to(heatpump_home_path)
    end

    it 'leads the timeframe select to the heat pump page too' do
      get heatpump_savings_path(timeframe: '2026-01', TimeframeSelectModal::PARAM => '1'), headers: { 'Turbo-Frame' => Ui::TurboModal::Component::FRAME }

      expect(response).to redirect_to(heatpump_home_path)
    end
  end
end
