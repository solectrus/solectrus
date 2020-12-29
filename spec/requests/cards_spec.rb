describe 'Cards' do
  describe 'GET /' do
    it 'works!', vcr: true do
      get cards_path
      expect(response).to have_http_status(:ok)
    end
  end
end
