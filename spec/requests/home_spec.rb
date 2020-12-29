describe 'Home' do
  describe 'GET /' do
    it 'works!' do
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end
end
