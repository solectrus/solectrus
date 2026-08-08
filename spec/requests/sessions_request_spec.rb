describe 'Sessions' do
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

      expect(response).to redirect_to(balance_home_path)

      jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      expect(jar.signed[:admin]).to be true
    end

    # ADMIN_PASSWORD is the only thing between a reachable instance and full
    # access, and it is checked here and on the OAuth authorization page.
    # Throttling one entrance and not the other would only decide which door an
    # attacker knocks on.
    describe 'guessing the password' do
      def guess(times)
        times.times do
          post '/login', params: { admin_user: { password: 'invalid' } }
        end
      end

      it 'stops answering after ten attempts from one address' do
        guess(10)
        expect(response).to have_http_status(:unauthorized)

        guess(1)
        expect(response).to have_http_status(:too_many_requests)
        expect(response.body).to include(I18n.t('login.throttled'))
      end

      it 'grants no session once the limit is reached, right password or not' do
        guess(11)

        post '/login', params: { admin_user: { username: 'admin', password: } }

        expect(response).to have_http_status(:too_many_requests)
        jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
        expect(jar.signed[:admin]).to be_nil
      end
    end

    it 'redirects to return_to path for valid password' do
      post '/login',
           params: {
             admin_user: {
               username: 'admin',
               password:,
             },
             return_to: '/forecast',
           }

      expect(response).to redirect_to('/forecast')
    end

    context 'with malicious return_to' do
      [
        '//evil.com',
        '/\\evil.com',
        'http://evil.com',
        'https://evil.com/path',
        'javascript:alert(1)',
        'evil.com',
      ].each do |bad_path|
        it "ignores #{bad_path.inspect} and redirects to root" do
          post '/login',
               params: {
                 admin_user: {
                   username: 'admin',
                   password:,
                 },
                 return_to: bad_path,
               }

          expect(response).to redirect_to('/')
        end
      end
    end

    it 'sets cookie with httponly and SameSite flags' do
      post '/login', params: { admin_user: { username: 'admin', password: } }

      admin_cookie =
        response.headers['Set-Cookie'].find { |c| c.start_with?('admin=') }
      expect(admin_cookie).to include('httponly')
      expect(admin_cookie).to include('samesite=lax')
    end
  end

  describe 'DELETE /logout' do
    it 'resets session and redirects' do
      login_as_admin
      delete '/logout'

      expect(response).to redirect_to(balance_home_path)

      jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      expect(jar.signed[:admin]).to be_nil
    end

    it 'redirects to return_to path' do
      login_as_admin
      delete '/logout', params: { return_to: '/forecast' }

      expect(response).to redirect_to('/forecast')
    end

    context 'with malicious return_to' do
      [
        '//evil.com',
        '/\\evil.com',
        'http://evil.com',
        'https://evil.com/path',
        'javascript:alert(1)',
        'evil.com',
      ].each do |bad_path|
        it "ignores #{bad_path.inspect} and redirects to root" do
          login_as_admin
          delete '/logout', params: { return_to: bad_path }

          expect(response).to redirect_to('/')
        end
      end
    end
  end
end
