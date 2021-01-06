describe 'Stats' do
  describe 'GET /' do
    context 'with params' do
      it 'renders', vcr: true do
        get stats_path(timeframe: 'now', field: 'house_power'),
            headers: { 'ACCEPT' => 'text/html; turbo-stream, text/html, application/xhtml+xml' }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
