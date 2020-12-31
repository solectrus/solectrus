describe 'Home' do
  describe 'GET /' do
    context 'without params' do
      it 'redirects' do
        get root_path
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'with params' do
      it 'renders' do
        get root_path(timeframe: 'current')
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
