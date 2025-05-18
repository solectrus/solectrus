describe 'Stats', vcr: { cassette_name: 'version' } do
  describe 'GET /stats' do
    it_behaves_like 'localized request', '/stats/house_power/now'
    it_behaves_like 'sponsoring redirects', '/stats/house_power/now'

    context 'with turbo_frame request' do
      it 'renders' do
        get house_stats_path(sensor: 'house_power', timeframe: 'now'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with default request' do
      it 'redirects' do
        get house_stats_path(sensor: 'house_power', timeframe: 'now')

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
