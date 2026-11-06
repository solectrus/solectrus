describe 'Insights' do
  subject(:page) { Capybara.string(response.body) }

  before do
    create_summary(
      date: Date.new(2025, 1, 1),
      values: [
        [:inverter_power, :sum, 20_000],
        [:inverter_power_1, :sum, 12_345],
        [:battery_charging_power, :sum, 8000],
        [:battery_charging_power_grid, :sum, 2000],
        [:battery_discharging_power, :sum, 6000],
        [:custom_power_01, :sum, 4000],
        [:custom_power_01_grid, :sum, 1000],
      ],
    )
  end

  def get_insights(sensor_name, timeframe: '2025-01')
    get insights_path(sensor_name:, timeframe:),
        headers: {
          'Turbo-Frame' => 'modal',
        }
  end

  # Everyone sees what the tooltip of a balance segment shows
  context 'without the permission' do
    before { stub_feature }

    it 'shows the values of the tooltip' do
      get_insights('inverter_power')

      expect(page).to have_css('.insights-heading-total', text: '20.000 kWh')
      expect(page).to have_css('.insights-row', text: 'CO₂ reduction')
    end

    it 'shows the teaser in place of the other figures' do
      get_insights('inverter_power')

      expect(page).to have_link(href: sponsoring_path)
      expect(page).to have_no_css('.insights-row', text: 'Minimum')
      expect(page).to have_no_css('.insights-row', text: 'per kWp')
    end

    it 'shows no grid share of the Power Splitter' do
      get_insights('battery_charging_power')

      expect(page).to have_no_css('.splitted-costs-ratio')
    end

    # Only a page with a permission shows these sensors
    %w[custom_power_01 inverter_power_1 heatpump_heating_power].each do |name|
      it "shows no value of #{name}" do
        get_insights(name)

        expect(page).to have_no_css('.insights-heading-total')
        expect(page).to have_link(href: sponsoring_path)
      end
    end

    # Only a sponsor has relative periods
    it 'shows no value of a relative period' do
      get_insights('inverter_power', timeframe: 'P30D')

      expect(page).to have_no_css('.insights-heading-total')
      expect(page).to have_no_css('.insights-row', text: 'CO₂ reduction')
    end
  end

  context 'with the permission' do
    before { stub_feature(:insights, :power_splitter, :custom_consumer) }

    it 'shows all figures' do
      get_insights('battery_charging_power')

      expect(page).to have_css('.splitted-costs-ratio')
      expect(page).to have_css('.insights-row', text: 'Minimum')
      expect(page).to have_no_link(href: sponsoring_path)
    end

    it 'shows the grid share of a consumer' do
      get_insights('custom_power_01')

      expect(page).to have_css('.splitted-costs-ratio', text: '75 %')
    end

    context 'with a consumer that is not configured' do
      before { Sensor::Config.setup(ENV.to_h.except('INFLUX_SENSOR_CUSTOM_POWER_02')) }
      after { Sensor::Config.setup(ENV) }

      it 'shows no costs' do
        get_insights('custom_power_02')

        expect(response).to have_http_status(:ok)
        expect(page).to have_no_css('.splitted-costs')
      end
    end

    it 'shows the values of a relative period' do
      get_insights('inverter_power', timeframe: 'P30D')

      expect(page).to have_css('.insights-heading-total')
    end

    # The referer names the page that holds the frame, and a day leads to
    # that page
    describe 'the link of a day' do
      def get_insights_from(referer)
        get insights_path(sensor_name: 'inverter_power_1', timeframe: '2025-01'),
            headers: {
              'Turbo-Frame' => 'modal',
              'Referer' => referer,
            }
      end

      it 'leads to the page that holds the frame' do
        get_insights_from('http://www.example.com/inverter/inverter_power_1/2025-01')

        expect(page).to have_link(href: '/inverter/inverter_power_1/2025-01-01')
      end

      it 'leads to the balance for a referer that is no address' do
        get_insights_from('http://www.example.com/inverter/a b')

        expect(page).to have_link(href: '/inverter_power_1/2025-01-01')
      end
    end
  end
end
