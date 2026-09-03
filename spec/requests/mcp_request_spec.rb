describe 'MCP' do
  # Request specs run against host www.example.com, so issuer/resource are
  # derived from that base URL.
  let(:base_url) { 'http://www.example.com' }
  let(:modern_protocol_version) { '2026-07-28' }
  let(:access_token) { McpOauth.encode_access_token(base_url:) }
  let(:tools_list) do
    { jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} }
  end

  def post_mcp(payload, token: access_token, origin: nil)
    headers = {
      'CONTENT_TYPE' => 'application/json',
      'ACCEPT' => 'application/json, text/event-stream',
    }
    headers['Authorization'] = "Bearer #{token}" if token
    headers['Origin'] = origin if origin

    post '/mcp', params: payload.to_json, headers:
  end

  # The same request on the stateless lifecycle of MCP 2026-07-28: the version
  # and the client capabilities ride in the `_meta` envelope, and the mirror
  # headers repeat the version and the method so an intermediary can route
  # without parsing the body.
  def post_mcp_modern(payload, token: access_token)
    meta = {
      'io.modelcontextprotocol/protocolVersion' => modern_protocol_version,
      'io.modelcontextprotocol/clientCapabilities' => {},
    }
    envelope =
      payload.merge(params: (payload[:params] || {}).merge(_meta: meta))

    post '/mcp',
         params: envelope.to_json,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'ACCEPT' => 'application/json, text/event-stream',
           'Authorization' => "Bearer #{token}",
           'MCP-Protocol-Version' => modern_protocol_version,
           'Mcp-Method' => payload[:method],
         }
  end

  describe 'GET /mcp' do
    context 'when MCP is disabled (default)' do
      it 'returns http not found' do
        get '/mcp'

        expect(response).to have_http_status(:not_found)
      end
    end

    # Sponsorship can lapse after MCP was enabled, so mcp_enabled stays true
    # while the sponsor policy turns false. The page must go invisible then.
    context 'when the operator is no longer a sponsor' do
      before do
        Setting.mcp_enabled = true
        allow(ApplicationPolicy).to receive(:mcp?).and_return(false)
      end

      it 'returns http not found' do
        get '/mcp'

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when MCP is enabled' do
      before do
        Setting.mcp_enabled = true
        allow(ApplicationPolicy).to receive(:mcp?).and_return(true)
      end

      it 'returns http not found for anonymous visitors' do
        get '/mcp'

        expect(response).to have_http_status(:not_found)
      end

      context 'when logged in as admin' do
        before { login_as_admin }

        it 'renders a guide with the endpoint URL' do
          get '/mcp'

          expect(response).to have_http_status(:success)
          expect(response.body).to include('http://www.example.com/mcp')
          expect(response.body).to include(I18n.t('mcp_info.title'))
        end
      end

      # An MCP client asking for the GET stream is not a browser looking for a
      # guide. Streamable HTTP requires 405 where a server offers no such
      # stream, so the client stops waiting for one; the 404 it used to get
      # reads as "wrong URL" and sends it rediscovering an endpoint that is
      # right here.
      context 'when an MCP client asks for the event stream' do
        it 'returns http method not allowed, naming what is allowed' do
          get '/mcp', headers: { 'Accept' => 'text/event-stream' }

          expect(response).to have_http_status(:method_not_allowed)
          expect(response.headers['Allow']).to eq('POST')
        end

        it 'still hides the endpoint when MCP is disabled' do
          Setting.mcp_enabled = false

          get '/mcp', headers: { 'Accept' => 'text/event-stream' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  # Session termination, which a stateless transport has none of. Answering 404
  # said "no endpoint here", which is the one thing that is not true.
  describe 'DELETE /mcp' do
    context 'when MCP is enabled' do
      before do
        Setting.mcp_enabled = true
        allow(ApplicationPolicy).to receive(:mcp?).and_return(true)
      end

      it 'returns http method not allowed, naming what is allowed' do
        delete '/mcp'

        expect(response).to have_http_status(:method_not_allowed)
        expect(response.headers['Allow']).to eq('POST')
      end
    end

    context 'when MCP is disabled (default)' do
      it 'stays invisible' do
        delete '/mcp'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /mcp' do
    context 'when MCP is disabled (default)' do
      it 'returns http not found, even with a valid token' do
        post_mcp(tools_list)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when MCP is enabled but the operator is not a sponsor' do
      before do
        Setting.mcp_enabled = true
        allow(ApplicationPolicy).to receive(:mcp?).and_return(false)
      end

      it 'returns http not found, even with a valid token' do
        post_mcp(tools_list)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when MCP is enabled' do
      before do
        Setting.mcp_enabled = true
        allow(ApplicationPolicy).to receive(:mcp?).and_return(true)
      end

      context 'without a token' do
        it 'returns http unauthorized with a resource_metadata challenge' do
          post_mcp(tools_list, token: nil)

          expect(response).to have_http_status(:unauthorized)
          expect(response.headers['WWW-Authenticate']).to eq(
            'Bearer resource_metadata=' \
              '"http://www.example.com/.well-known/oauth-protected-resource"',
          )
        end
      end

      context 'with a malformed token' do
        it 'returns http unauthorized' do
          post_mcp(tools_list, token: 'not-a-jwt')

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'with a token issued for a different resource' do
        it 'returns http unauthorized' do
          other = McpOauth.encode_access_token(base_url: 'http://evil.example')

          post_mcp(tools_list, token: other)

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'with a valid access token' do
        it 'responds to the initialize handshake' do
          post_mcp(
            {
              jsonrpc: '2.0',
              id: 1,
              method: 'initialize',
              params: {
                protocolVersion: '2025-06-18',
                capabilities: {},
                clientInfo: {
                  name: 'spec',
                  version: '1',
                },
              },
            },
          )

          expect(response).to have_http_status(:success)
          body = response.parsed_body
          expect(body.dig('result', 'serverInfo', 'name')).to eq('solectrus')

          # Reports the running SOLECTRUS version, not a static placeholder.
          expect(body.dig('result', 'serverInfo', 'version')).to eq(
            Rails.configuration.x.git.commit_version,
          )
        end

        # Browser-based AI clients (e.g. claude.ai web) call /mcp cross-origin.
        # The transport's DNS rebinding protection is deliberately disabled (see
        # McpController), so a foreign Origin must not be rejected. Guards against
        # a future mcp gem re-enabling that protection by default.
        it 'accepts a request from a foreign browser Origin' do
          post_mcp(tools_list, origin: 'https://claude.ai')

          expect(response).to have_http_status(:success)
        end

        it 'lists the available tools' do
          post_mcp(tools_list)

          expect(response).to have_http_status(:success)
          names = response.parsed_body.dig('result', 'tools').pluck('name')
          expect(names).to contain_exactly(
            'list_sensors',
            'get_sensor_details',
            'get_system_info',
            'get_prices',
            'get_current_values',
            'get_totals',
            'get_periods',
            'get_ranking',
            'get_series',
            'get_forecast',
            'get_amortization',
            'get_cash_flows',
          )
        end

        # The SEP-2549 cache hints are mandatory on tools/list at 2026-07-28,
        # and the mcp gem emits our values only when the server is built with
        # them. Without them a client sees the spec default `ttlMs: 0` and
        # refetches the ~28 KB list on every turn.
        it 'states how long the tool list may be cached' do
          post_mcp(tools_list)

          expect(response.parsed_body['result']).to include(
            'ttlMs' => 3_600_000,
            'cacheScope' => 'private',
          )
        end

        # The stateless lifecycle of MCP 2026-07-28 (SEP-2575) is what browser
        # clients on that revision speak: no initialize handshake, a `_meta`
        # envelope per request instead. Its results carry `resultType`, which
        # a legacy result must not have.
        it 'answers a modern request with the required result members' do
          post_mcp_modern(tools_list)

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['result']).to include(
            'resultType' => 'complete',
            'ttlMs' => 3_600_000,
            'cacheScope' => 'private',
          )
        end

        # The counterpart: a client that came through the initialize handshake
        # speaks a pre-2026 revision, which has no `resultType`. Such a client
        # reads the unknown member as an error, so it must stay absent.
        it 'leaves a legacy result unstamped' do
          post_mcp(tools_list)

          expect(response.parsed_body['result']).not_to have_key('resultType')
        end

        # Sessionless discovery (SEP-2575) lets a client probe the server
        # before - or instead of - the initialize handshake.
        it 'answers sessionless discovery with every required member' do
          post_mcp({ jsonrpc: '2.0', id: 1, method: 'server/discover' })

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['result']).to include(
            'resultType' => 'complete',
            'ttlMs' => 3_600_000,
            'cacheScope' => 'private',
            'supportedVersions' => include('2026-07-28'),
          )
        end
      end
    end
  end
end
