# Insights and the timeframe select answer a Turbo Frame. A direct request has
# no frame to fill, so it goes to the home page that shows the sensor. That
# page keeps both the sensor and the timeframe.
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
  end

  describe 'GET /timeframe-select/:sensor_name/:timeframe' do
    it_behaves_like 'a frame that falls back',
                    path_helper: :timeframe_select_path
  end
end
