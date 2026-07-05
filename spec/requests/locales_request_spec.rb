describe 'Locales' do
  describe 'PATCH /locale' do
    it 'persists the chosen locale in a cookie' do
      patch '/locale', params: { locale: 'de' }

      expect(cookies[:locale]).to eq('de')
    end

    it 'sets the cookie with httponly and SameSite flags' do
      patch '/locale', params: { locale: 'de' }

      locale_cookie =
        Array(response.headers['Set-Cookie'])
          .join("\n")
          .lines
          .find { |c| c.start_with?('locale=') }
      expect(locale_cookie).to include('httponly')
      expect(locale_cookie).to include('samesite=lax')
    end

    it 'ignores an unsupported locale' do
      patch '/locale', params: { locale: 'fr' }

      expect(cookies[:locale]).to be_blank
    end

    it 'redirects back' do
      patch '/locale',
            params: { locale: 'de' },
            headers: { 'HTTP_REFERER' => '/sponsoring' }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to('/sponsoring')
    end

    it 'makes subsequent requests use the chosen locale' do
      patch '/locale', params: { locale: 'de' }
      get '/login', headers: { 'Accept-Language' => 'en' }

      expect(response.body).to include('lang="de"')
    end
  end
end
