describe 'Sessions', vcr: { cassette_name: 'version' } do
  let(:password) { 't0ps3cr3t' }

  before do
    allow(Rails.configuration.x).to receive(:admin_password).and_return(
      password,
    )
  end

  it_behaves_like 'localized request', '/login'

  describe 'GET /login' do
    it 'is successful' do
      get '/login'

      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /login' do
    it 'fails for invalid password' do
      post '/login', params: { admin_user: { password: 'invalid' } }

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include(I18n.t('errors.messages.invalid'))
      expect(response.body).not_to include(password)

      jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      expect(jar.signed[:admin]).to be_nil
    end

    it 'set session and redirects for valid password' do
      post '/login', params: { admin_user: { username: 'admin', password: } }

      expect(response).to redirect_to(root_path)

      jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      expect(jar.signed[:admin]).to be true
    end
  end

  describe 'DELETE /logout' do
    it 'resets session and redirects' do
      login_as_admin
      delete '/logout'

      expect(response).to redirect_to(root_path)

      jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      expect(jar.signed[:admin]).to be_nil
    end
  end
end
