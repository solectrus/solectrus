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
      it 'shows the unlock form with status 403' do
        get '/lockup/unlock'

        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include(I18n.t('lockup.headline'))
      end
    end

    describe 'POST /lockup/unlock' do
      context 'with blank codeword' do
        it 'shows the unlock form with status 403' do
          post '/lockup/unlock', params: { lockup: { codeword: '' } }

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include(I18n.t('lockup.headline'))
        end
      end

      context 'with correct codeword' do
        it 'sets cookie and redirects to root' do
          post '/lockup/unlock',
               params: { lockup: { codeword: } }

          expect(response).to redirect_to('/')
          expect(response).to have_http_status(:see_other)
        end
      end

      context 'with correct codeword and return_to' do
        it 'redirects to return_to path' do
          post '/lockup/unlock',
               params: { lockup: { codeword:, return_to: '/forecast' } }

          expect(response).to redirect_to('/forecast')
        end
      end

      context 'with correct codeword and malicious return_to' do
        [
          '//evil.com',
          '/\\evil.com',
          'http://evil.com',
          'https://evil.com/path',
          'javascript:alert(1)',
          'evil.com',
        ].each do |bad_path|
          it "ignores #{bad_path.inspect} and redirects to root" do
            post '/lockup/unlock',
                 params: { lockup: { codeword:, return_to: bad_path } }

            expect(response).to redirect_to('/')
          end
        end
      end

      context 'with incorrect codeword' do
        it 'shows error message' do
          post '/lockup/unlock',
               params: { lockup: { codeword: 'wrong' } }

          expect(response).to have_http_status(:forbidden)
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

    context 'with an unsigned cookie holding the codeword' do
      before { cookies[:lockup] = codeword }

      it 'is rejected and redirects to unlock page' do
        get '/'

        expect(response).to redirect_to(%r{/lockup/unlock})
      end
    end
  end

  context 'when LOCKUP_CODEWORD is not set' do
    it 'does not redirect to unlock page' do
      get '/'

      expect(response).not_to redirect_to(%r{/lockup/unlock})
    end

    describe 'GET /lockup/unlock' do
      it 'redirects to root' do
        get '/lockup/unlock'

        expect(response).to redirect_to('/')
      end
    end

    describe 'POST /lockup/unlock' do
      it 'redirects to root without setting a cookie' do
        post '/lockup/unlock', params: { lockup: { codeword: 'anything' } }

        expect(response).to redirect_to('/')
        expect(cookies[:lockup]).to be_blank
      end
    end
  end
end
