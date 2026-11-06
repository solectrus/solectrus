# Insights answer a Turbo Frame. A direct request has no frame to fill, so it
# goes to the home page that shows the sensor. That page keeps both the sensor
# and the timeframe.
describe 'Frame fallback' do
  shared_examples 'a frame that falls back' do |path_helper:|
    it 'sends a heat pump sensor to the heat pump page' do
      get public_send(path_helper, sensor_name: 'heatpump_cop', timeframe: '2025')

      expect(response).to redirect_to(
        heatpump_home_path(sensor_name: 'heatpump_cop', timeframe: '2025'),
      )
    end

    it 'sends a balance sensor to the balance page' do
      get public_send(path_helper, sensor_name: 'house_power', timeframe: '2025')

      expect(response).to redirect_to(
        balance_home_path(sensor_name: 'house_power', timeframe: '2025'),
      )
    end
  end

  describe 'GET /insights/:sensor_name/:timeframe' do
    it_behaves_like 'a frame that falls back', path_helper: :insights_path

    # The referer names the page that holds the frame. A browser can omit it.
    it 'renders the frame when the request has no referer' do
      get insights_path(sensor_name: 'house_power', timeframe: '2025'),
          headers: {
            'Turbo-Frame' => 'insights',
          }

      expect(response).to have_http_status(:ok)
    end
  end

  # The stats and the charts of a home page answer a Turbo Frame as well. A
  # direct request goes to the home page itself, with the sensor and the
  # timeframe of the address.
  describe 'the stats and the charts of a home page' do
    [
      %i[balance stats house_power],
      %i[balance charts house_power],
      %i[heatpump stats heatpump_cop],
      %i[heatpump charts heatpump_cop],
      %i[house stats house_power],
      %i[house charts house_power],
      %i[inverter stats inverter_power_1],
      %i[inverter charts inverter_power_1],
    ].each do |page, frame, sensor_name|
      it "sends the #{frame} of the #{page} page to the page" do
        get public_send(:"#{page}_#{frame}_path", sensor_name:, timeframe: 'now')

        expect(response).to redirect_to(
          public_send(:"#{page}_home_path", sensor_name:, timeframe: 'now'),
        )
      end
    end
  end
end
