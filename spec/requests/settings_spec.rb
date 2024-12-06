describe 'Settings', vcr: { cassette_name: 'version' } do
  describe 'GET /settings' do
    it 'returns http success' do
      get '/settings'
      expect(response).to redirect_to('/settings/general')
    end
  end

  describe 'GET /settings/general' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/settings/general'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get '/settings/general'
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'PATCH /settings/general' do
    context 'when not logged in' do
      it 'fails' do
        patch '/settings/general', params: { setting: { plant_name: 'Test' } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        patch '/settings/general',
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

  describe 'GET /settings/consumers' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/settings/consumers'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get '/settings/consumers'
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'PATCH /settings/consumers' do
    context 'when not logged in' do
      it 'fails' do
        patch '/settings/consumers',
              params: {
                setting: {
                  custom_name_01: 'Test',
                },
              }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        patch '/settings/consumers',
              params: {
                setting: {
                  custom_name_01: 'Test1',
                  custom_name_02: 'Test2',
                },
              }
        expect(response).to have_http_status(:success)

        expect(Setting.custom_name_01).to eq('Test1')
        expect(Setting.custom_name_02).to eq('Test2')
      end
    end
  end
end
