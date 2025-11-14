describe 'Forecast' do
  describe 'GET /forecast' do
    it_behaves_like 'localized request', '/forecast'
    it_behaves_like 'sponsoring redirects', '/forecast'

    context 'when HTML request' do
      it 'renders the page' do
        get forecast_path
        expect(response).to have_http_status(:ok)
      end

      it 'includes turbo frames for navigation and chart' do
        get forecast_path
        expect(response.body).to include('turbo-frame id="forecast-timeframe"')
        expect(response.body).to include('turbo-frame id="forecast-chart"')
      end
    end

    context 'when turbo_frame request' do
      it 'renders turbo_stream response' do
        get forecast_path,
            headers: {
              'Turbo-Frame' => 'forecast-chart',
            }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'updates both timeframe and chart frames' do
        get forecast_path,
            headers: {
              'Turbo-Frame' => 'forecast-chart',
            }
        expect(response.body).to include('turbo-stream action="update"')
        expect(response.body).to include('target="forecast-timeframe"')
        expect(response.body).to include('target="forecast-chart"')
      end
    end
  end
end
