describe 'Browser Check', type: :request do
  context 'with outdated browser' do
    let(:headers) do
      {
        'HTTP_USER_AGENT' =>
          'Mozilla/5.0 (Linux) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.125 Mobile Safari/537.36',
      }
    end

    describe 'GET /skip-browser-check' do
      it 'sets cookie' do
        get('/skip-browser-check', headers:)

        expect(response).to redirect_to(root_path)
        expect(response.cookies['skip_browser_check']).to eq('true')
      end
    end

    describe 'access with an outdated browser' do
      context 'when cookie is not set' do
        it 'rejects access' do
          get('/', headers:)

          expect(response).to have_http_status(:not_acceptable)
          expect(response.body).to include('Your browser is not supported')
        end
      end

      context 'when cookie is set' do
        before { cookies['skip_browser_check'] = 'true' }

        it 'allows access' do
          get('/', headers:)

          expect(response).to have_http_status(:redirect)
        end
      end
    end
  end

  context 'with modern browser' do
    let(:headers) do
      {
        'HTTP_USER_AGENT' =>
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
      }
    end

    it 'allows access' do
      get('/', headers:)

      expect(response).to have_http_status(:redirect)
    end
  end
end
