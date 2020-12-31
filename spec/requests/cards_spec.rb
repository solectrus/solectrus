describe 'Cards' do
  describe 'GET /' do
    context 'without params' do
      it 'redirects' do
        get cards_path
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'with params' do
      it 'renders', vcr: true do
        get cards_path(timeframe: 'current')
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
