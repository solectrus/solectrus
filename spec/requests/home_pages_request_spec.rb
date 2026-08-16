# The balance, house, heat pump and inverter pages each show their own sensors
# only. A sensor of another page has to fall back to the page default instead
# of rendering a chart the page never offers.
describe 'Home pages' do
  shared_examples 'a page with its own sensors' do |path_helper:, default_sensor:, own_sensor:, foreign_sensor:|
    let(:default_path) do
      public_send(path_helper, sensor_name: default_sensor, timeframe: 'now')
    end

    it 'redirects a sensor of another page to the default' do
      get public_send(path_helper, sensor_name: foreign_sensor, timeframe: 'now')

      expect(response).to redirect_to(default_path)
    end

    it 'redirects a request without params to the default' do
      get public_send(path_helper)

      expect(response).to redirect_to(default_path)
    end

    it 'renders a sensor of this page' do
      get public_send(path_helper, sensor_name: own_sensor, timeframe: 'now')

      expect(response).to have_http_status(:ok)
    end

    # Only the sensor is wrong, so the user keeps the year they asked for.
    it 'keeps the timeframe when it swaps the sensor' do
      get public_send(path_helper, sensor_name: foreign_sensor, timeframe: '2025')

      expect(response).to redirect_to(
        public_send(path_helper, sensor_name: default_sensor, timeframe: '2025'),
      )
    end
  end

  describe 'GET /' do
    it_behaves_like 'a page with its own sensors',
                    path_helper: :balance_home_path,
                    default_sensor: 'power_balance',
                    # Expanded from the :grid_power dropdown entry
                    own_sensor: 'grid_import_power',
                    foreign_sensor: 'heatpump_heating_power'
  end

  describe 'GET /house' do
    it_behaves_like 'a page with its own sensors',
                    path_helper: :house_home_path,
                    default_sensor: 'house_power',
                    own_sensor: 'custom_power_01',
                    foreign_sensor: 'grid_import_power'
  end

  describe 'GET /heatpump' do
    it_behaves_like 'a page with its own sensors',
                    path_helper: :heatpump_home_path,
                    default_sensor: 'heatpump_heating_power',
                    own_sensor: 'heatpump_cop',
                    foreign_sensor: 'grid_import_power'
  end

  describe 'GET /inverter' do
    it_behaves_like 'a page with its own sensors',
                    path_helper: :inverter_home_path,
                    default_sensor: 'inverter_power',
                    own_sensor: 'inverter_power_1',
                    foreign_sensor: 'grid_import_power'

    # With inverter_as_total the balance shows the sum only, so a single
    # inverter belongs to this page. Covered here because the system spec for
    # the balance page no longer visits these URLs.
    it 'takes a single inverter that the balance page rejects' do
      expect(Setting.inverter_as_total).to be(true)

      get balance_home_path(sensor_name: 'inverter_power_1', timeframe: 'now')
      expect(response).to have_http_status(:redirect)

      get inverter_home_path(sensor_name: 'inverter_power_1', timeframe: 'now')
      expect(response).to have_http_status(:ok)
    end

    # The settings can switch this page off while the single inverters keep
    # their charts. The balance takes them over then, so a link from a Top10
    # row or a heatmap tile still renders instead of going to the default.
    it 'gives a single inverter back to the balance when switched off' do
      allow(Setting).to receive(:enable_multi_inverter).and_return(false)

      get balance_home_path(sensor_name: 'inverter_power_1', timeframe: 'now')
      expect(response).to have_http_status(:ok)
    end
  end

  # Only the pages that can show a forecast hand a future day over to it. The
  # other two have nothing to show and go back to the present.
  describe 'a future timeframe' do
    let(:tomorrow) { Date.tomorrow.to_fs(:iso8601) }

    it 'goes to the forecast on the balance page' do
      expect(Sensor::Config.exists?(:inverter_power_forecast)).to be(true)

      get balance_home_path(sensor_name: 'inverter_power', timeframe: tomorrow)

      expect(response).to redirect_to(forecast_path)
    end

    it 'goes back to now on the house page' do
      get house_home_path(sensor_name: 'house_power', timeframe: tomorrow)

      expect(response).to redirect_to(
        house_home_path(sensor_name: 'house_power', timeframe: 'now'),
      )
    end
  end
end
