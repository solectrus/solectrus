describe 'Settings' do
  describe 'GET /settings' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/settings'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'lists the settings sections' do
        get '/settings'

        expect(response).to have_http_status(:success)
        expect(response.body).to include(
          'href="/settings/general"',
          'href="/settings/sensors"',
          'href="/settings/prices/electricity"',
          'href="/settings/prices/feed_in"',
          'href="/settings/cash_flows"',
        )
      end
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
                },
              }
        expect(response).to redirect_to(edit_settings_general_path)

        expect(Setting.plant_name).to eq('Test')
        expect(Setting.operator_name).to eq('John')
      end

      context 'when a sponsor' do
        before { allow(ApplicationPolicy).to receive(:mcp?).and_return(true) }

        it 'enables MCP without rotating the signing secret' do
          expect do
            patch '/settings/general',
                  params: {
                    setting: {
                      mcp_enabled: '1',
                    },
                  }
          end.not_to change(Setting, :mcp_oauth_secret)
          expect(response).to redirect_to(edit_settings_general_path)

          expect(Setting.mcp_enabled).to be(true)
        end

        it 'disables MCP and drops all connected clients' do
          Setting.mcp_enabled = true
          token = McpOauth.encode_access_token(base_url: 'http://www.example.com')

          patch '/settings/general',
                params: {
                  setting: {
                    mcp_enabled: '0',
                  },
                }
          expect(response).to redirect_to(edit_settings_general_path)

          expect(Setting.mcp_enabled).to be(false)
          # Rotating the signing secret invalidates every issued token.
          expect(
            McpOauth.valid_access_token?(token, base_url: 'http://www.example.com'),
          ).to be_nil
        end
      end

      context 'when not a sponsor' do
        before { allow(ApplicationPolicy).to receive(:mcp?).and_return(false) }

        it 'refuses to enable MCP' do
          patch '/settings/general', params: { setting: { mcp_enabled: '1' } }
          expect(response).to redirect_to(edit_settings_general_path)

          expect(Setting.mcp_enabled).to be(false)
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

  describe 'PATCH /settings/prices/:id' do
    before { login_as_admin }

    let!(:price) do
      Price.create!(
        name: :electricity,
        starts_at: Date.new(2024, 1, 1),
        value: 0.3,
      )
    end

    it 'responds with the updated list' do
      patch "/settings/prices/#{price.id}",
            params: { price: { note: 'New tariff' } },
            as: :turbo_stream

      expect(response.body).to include(
        '<turbo-stream action="update" target="list">',
      )
      expect(response.body).to include('New tariff')
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

      it 'lists the sensor groups' do
        get '/settings/sensors'

        expect(response.body).to include(
          'href="/settings/sensors/generators"',
          'href="/settings/sensors/consumers"',
        )
      end
    end
  end

  describe 'GET /settings/sensors/:section' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/settings/sensors/generators'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'shows the form of the group, leading back to the groups' do
        get '/settings/sensors/consumers'

        expect(response).to have_http_status(:success)

        html = response.parsed_body
        expect(html.at_css('input[name="sensor_names[custom_power_01]"]')).to be_present
        expect(html.at_css('input[name="sensor_names[inverter_power_1]"]')).to be_nil
        expect(html.at_css('.nav-title-bar')['data-parent']).to eq('/settings/sensors')
      end

      it 'redirects for an unknown group' do
        get '/settings/sensors/foo'
        expect(response).to redirect_to('/settings/sensors')
      end

      it 'redirects when the group has no sensors' do
        allow(Sensor::Config).to receive(:nameable_sensors).and_return([])

        get '/settings/sensors/battery'
        expect(response).to redirect_to('/settings/sensors')
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

      it 'keeps the names of the other groups when one group is saved' do
        patch '/settings/sensors',
              params: {
                sensor_names: {
                  inverter_power_1: 'Roof',
                },
              }
        patch '/settings/sensors',
              params: {
                sensor_names: {
                  custom_power_01: 'Washer',
                },
              },
              headers: {
                'HTTP_REFERER' => 'http://www.example.com/settings/sensors/consumers',
              }

        expect(response).to redirect_to('/settings/sensors/consumers')
        expect(Setting.sensor_names[:inverter_power_1]).to eq('Roof')
        expect(Setting.sensor_names[:custom_power_01]).to eq('Washer')
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
