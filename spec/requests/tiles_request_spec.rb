describe 'Tiles' do
  describe 'GET /tiles/:sensor_name/now' do
    it 'renders a live tile for an ordinary sensor' do
      add_influx_point(
        name: Sensor::Config.measurement(:house_power),
        fields: {
          Sensor::Config.field(:house_power) => 900.0,
        },
      )

      get '/tiles/house_power/now'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('tile-house_power-now')
    end

    # The sensor name comes straight from the URL, so it could name a power
    # split - which divides a period and has no reading of an instant. The
    # route already refuses it, because it is scoped to chart_enabled? sensors
    # and no power_splitter sensor defines a chart. Pinned here so a chart
    # added to a split later does not silently open a live path to it.
    it 'has no route for a power split' do
      stub_feature(:power_splitter)

      get '/tiles/house_power_grid/now'

      expect(response).to have_http_status(:not_found)
    end
  end
end
