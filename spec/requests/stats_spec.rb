describe 'Stats', vcr: { cassette_name: 'version' } do
  describe 'GET /' do
    context 'with params' do
      it 'renders' do
        get stats_path(field: 'house_power'),
            headers: {
              'ACCEPT' =>
                'text/vnd.turbo-stream.html, text/html, application/xhtml+xml',
            }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
