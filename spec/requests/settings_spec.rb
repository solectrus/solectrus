describe 'Settings', vcr: { cassette_name: 'version' } do
  describe 'GET /settings' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/settings'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get '/settings'
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'PATCH /settings' do
    context 'when not logged in' do
      it 'fails' do
        patch '/settings', params: { setting: { plant_name: 'Test' } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        patch '/settings',
              params: {
                setting: {
                  plant_name: 'Test',
                  operator_name: 'John',
                  opportunity_costs: true,
                },
              }
        expect(response).to have_http_status(:success)

        expect(Setting.plant_name).to eq('Test')
        expect(Setting.operator_name).to eq('John')
        expect(Setting.opportunity_costs).to be_truthy
      end
    end
  end

  describe 'GET /settings/prices' do
    it_behaves_like 'localized request', '/settings/prices'

    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/settings/prices'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      context 'when name is "electricity"' do
        it 'returns http success' do
          get '/settings/prices/electricity'
          expect(response).to have_http_status(:success)
        end
      end

      context 'when name is "feed_in"' do
        it 'returns http success' do
          get '/settings/prices/feed_in'
          expect(response).to have_http_status(:success)
        end
      end

      context 'when name is not given' do
        it 'redirects' do
          get '/settings/prices'
          expect(response).to have_http_status(:redirect)
        end
      end
    end
  end
end
