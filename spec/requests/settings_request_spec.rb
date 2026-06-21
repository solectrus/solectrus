describe 'Settings' do
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

      context 'when a sponsor' do
        before { allow(ApplicationPolicy).to receive(:mcp?).and_return(true) }

        it 'does not generate an MCP token on GET' do
          Setting.mcp_token = nil

          get '/settings/general'

          expect(Setting.mcp_token).to be_blank
        end
      end

      context 'when not a sponsor' do
        before { allow(ApplicationPolicy).to receive(:mcp?).and_return(false) }

        it 'does not generate an MCP token' do
          Setting.mcp_token = nil

          get '/settings/general'

          expect(Setting.mcp_token).to be_blank
        end
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
                },
              }
        expect(response).to have_http_status(:success)

        expect(Setting.plant_name).to eq('Test')
        expect(Setting.operator_name).to eq('John')
      end

      context 'when a sponsor' do
        before { allow(ApplicationPolicy).to receive(:mcp?).and_return(true) }

        it 'enables MCP and generates an access token' do
          patch '/settings/general',
                params: {
                  setting: {
                    mcp_enabled: '1',
                  },
                }
          expect(response).to have_http_status(:success)

          expect(Setting.mcp_enabled).to be(true)
          expect(Setting.mcp_token).to be_present
        end

        it 'keeps an existing token when re-enabling MCP' do
          Setting.mcp_token = 'existing-token'

          patch '/settings/general', params: { setting: { mcp_enabled: '1' } }

          expect(Setting.mcp_token).to eq('existing-token')
        end

        it 'disables MCP' do
          Setting.mcp_enabled = true

          patch '/settings/general',
                params: {
                  setting: {
                    mcp_enabled: '0',
                  },
                }
          expect(response).to have_http_status(:success)

          expect(Setting.mcp_enabled).to be(false)
        end
      end

      context 'when not a sponsor' do
        before { allow(ApplicationPolicy).to receive(:mcp?).and_return(false) }

        it 'refuses to enable MCP' do
          patch '/settings/general', params: { setting: { mcp_enabled: '1' } }
          expect(response).to have_http_status(:success)

          expect(Setting.mcp_enabled).to be(false)
          expect(Setting.mcp_token).to be_blank
        end
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
                  inverter_power_1: 'Roof',
                  inverter_power_2: 'Fence',
                },
              }
        expect(response).to have_http_status(:redirect)

        expect(Setting.sensor_names[:custom_power_01]).to eq('Test1')
        expect(Setting.sensor_names[:custom_power_02]).to eq('Test2')
        expect(Setting.sensor_names[:inverter_power_1]).to eq('Roof')
        expect(Setting.sensor_names[:inverter_power_2]).to eq('Fence')
      end

      it 'does nothing for unknown keys' do
        patch '/settings/sensors', params: { sensor_names: { foo: 'Test1' } }
        expect(response).to have_http_status(:redirect)
      end

      it 'does nothing for unknown root key' do
        patch '/settings/sensors', params: { foo: { custom_power_01: 'Test1' } }
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
