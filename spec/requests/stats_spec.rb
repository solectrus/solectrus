describe 'Stats', vcr: { cassette_name: 'version' } do
  describe 'GET /stats' do
    it_behaves_like 'localized request', '/stats/house_power/now'
    it_behaves_like 'sponsoring redirects', '/stats/house_power/now'

    context 'with params' do
      it 'renders' do
        get house_stats_path(sensor: 'house_power', timeframe: 'now'),
            headers: {
              'ACCEPT' =>
                'text/vnd.turbo-stream.html, text/html, application/xhtml+xml',
            }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
