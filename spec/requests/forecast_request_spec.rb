describe 'Forecast' do
  describe 'GET /forecast' do
    let(:availability_query) do
      instance_double(Sensor::Query::ForecastAvailability)
    end

    before do
      allow(Sensor::Query::ForecastAvailability).to receive(:new).and_return(
        availability_query,
      )
      allow(availability_query).to receive(:call).and_return(
        Date.current + 6.days,
      )
    end

    it_behaves_like 'localized request', '/forecast'
    it_behaves_like 'sponsoring redirects', '/forecast'

    context 'when HTML request' do
      it 'renders the page' do
        get forecast_path
        expect(response).to have_http_status(:ok)
      end

      it 'includes turbo frames for navigation and charts' do
        get forecast_path
        expect(response.body).to include('turbo-frame id="forecast-timeframe"')
        expect(response.body).to include(
          'turbo-frame id="inverter-power-forecast-chart"',
        )
        expect(response.body).to include(
          'turbo-frame id="outdoor-temp-forecast-chart"',
        )
      end

      it 'enables swipe controller for navigation' do
        get forecast_path
        expect(response.body).to match(/data-controller="[^"]*swipe/)
      end

      it 'includes prev link for backward navigation' do
        get forecast_path
        expect(response.body).to include('data-nav="prev"')
      end
    end

    context 'when turbo_frame request to inverter power chart' do
      it 'renders turbo_stream response' do
        get forecast_chart_path(id: 'inverter_power'),
            headers: {
              'Turbo-Frame' => 'inverter-power-forecast-chart',
            }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'updates chart frame' do
        get forecast_chart_path(id: 'inverter_power'),
            headers: {
              'Turbo-Frame' => 'inverter-power-forecast-chart',
            }
        expect(response.body).to include('turbo-stream action="update"')
        expect(response.body).to include(
          'target="inverter-power-forecast-chart"',
        )
      end
    end

    context 'when turbo_frame request to outdoor temp chart' do
      it 'renders turbo_stream response' do
        get forecast_chart_path(id: 'outdoor_temp'),
            headers: {
              'Turbo-Frame' => 'outdoor-temp-forecast-chart',
            }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'updates outdoor temp chart frame' do
        get forecast_chart_path(id: 'outdoor_temp'),
            headers: {
              'Turbo-Frame' => 'outdoor-temp-forecast-chart',
            }
        expect(response.body).to include('turbo-stream action="update"')
        expect(response.body).to include('target="outdoor-temp-forecast-chart"')
      end
    end
  end
end
