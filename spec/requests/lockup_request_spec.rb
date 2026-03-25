describe 'Lockup' do
  let(:codeword) { 'secret123' }

  context 'when LOCKUP_CODEWORD is set' do
    before do
      allow(Rails.configuration.x).to receive(:lockup_codeword).and_return(
        codeword,
      )
    end

    describe 'GET /' do
      it 'redirects to unlock page' do
        get '/'

        expect(response).to redirect_to(%r{/lockup/unlock})
      end
    end

    describe 'GET /up' do
      it 'is not affected by lockup' do
        get '/up'

        expect(response).to have_http_status(:success)
      end
    end

    describe 'GET /lockup/unlock' do
      it 'shows the unlock form' do
        get '/lockup/unlock'

        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t('lockup.headline'))
      end
    end

    describe 'POST /lockup/unlock' do
      context 'with correct codeword' do
        it 'sets cookie and redirects to root' do
          post '/lockup/unlock',
               params: { lockup: { codeword: } }

          expect(response).to redirect_to('/')
        end
      end

      context 'with correct codeword and return_to' do
        it 'redirects to return_to path' do
          post '/lockup/unlock',
               params: { lockup: { codeword:, return_to: '/forecast' } }

          expect(response).to redirect_to('/forecast')
        end
      end

      context 'with incorrect codeword' do
        it 'shows error message' do
          post '/lockup/unlock',
               params: { lockup: { codeword: 'wrong' } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include(
            ERB::Util.html_escape(I18n.t('lockup.wrong')),
          )
        end
      end
    end

    context 'when already unlocked' do
      before do
        post '/lockup/unlock',
             params: { lockup: { codeword: } }
      end

      it 'does not redirect to unlock page' do
        get '/'

        expect(response).not_to redirect_to(%r{/lockup/unlock})
      end
    end

    context 'when codeword changes after unlock' do
      before do
        post '/lockup/unlock',
             params: { lockup: { codeword: } }
      end

      it 'requires re-authentication' do
        allow(Rails.configuration.x).to receive(:lockup_codeword).and_return(
          'new-codeword',
        )

        get '/'

        expect(response).to redirect_to(%r{/lockup/unlock})
      end
    end

    context 'with legacy unsigned cookie' do
      context 'when cookie contains correct codeword' do
        before do
          cookies[:lockup] = codeword.downcase
        end

        it 'migrates to signed cookie and grants access' do
          get '/'

          expect(response).not_to redirect_to(%r{/lockup/unlock})
        end
      end

      context 'when cookie contains correct codeword in different case' do
        before do
          cookies[:lockup] = codeword.upcase
        end

        it 'migrates to signed cookie and grants access' do
          get '/'

          expect(response).not_to redirect_to(%r{/lockup/unlock})
        end
      end

      context 'when cookie contains wrong value' do
        before do
          cookies[:lockup] = 'fakevalue'
        end

        it 'rejects and redirects to unlock page' do
          get '/'

          expect(response).to redirect_to(%r{/lockup/unlock})
        end
      end
    end
  end

  context 'when LOCKUP_CODEWORD is not set' do
    it 'does not redirect to unlock page' do
      get '/'

      expect(response).not_to redirect_to(%r{/lockup/unlock})
    end
  end
end
