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

  describe 'GET /settings/sensors' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/settings/sensors'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get '/settings/sensors'
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'PATCH /settings/sensors' do
    context 'when not logged in' do
      it 'fails' do
        patch '/settings/sensors',
              params: {
                setting: {
                  custom_power_01: 'Test',
                },
              }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        patch '/settings/sensors',
              params: {
                sensor_names: {
                  custom_power_01: 'Test1',
                  custom_power_02: 'Test2',
                  balcony_inverter_power: 'Fence',
                },
              }
        expect(response).to have_http_status(:success)

        expect(Setting.sensor_names[:custom_power_01]).to eq('Test1')
        expect(Setting.sensor_names[:custom_power_02]).to eq('Test2')
        expect(Setting.sensor_names[:balcony_inverter_power]).to eq('Fence')
      end

      it 'fails for unknown keys' do
        patch '/settings/sensors', params: { sensor_names: { foo: 'Test1' } }
        expect(response).to have_http_status(:bad_request)
      end

      it 'fails for unknown root key' do
        patch '/settings/sensors', params: { foo: { custom_power_01: 'Test1' } }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
