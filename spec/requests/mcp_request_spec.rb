describe 'MCP' do
  # Request specs run against host www.example.com, so issuer/resource are
  # derived from that base URL.
  let(:base_url) { 'http://www.example.com' }
  let(:access_token) { McpOauth.encode_access_token(base_url:) }
  let(:tools_list) do
    { jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} }
  end

  def post_mcp(payload, token: access_token)
    headers = {
      'CONTENT_TYPE' => 'application/json',
      'ACCEPT' => 'application/json, text/event-stream',
    }
    headers['Authorization'] = "Bearer #{token}" if token

    post '/mcp', params: payload.to_json, headers:
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

        it 'lists the available tools' do
          post_mcp(tools_list)

          expect(response).to have_http_status(:success)
          names = response.parsed_body.dig('result', 'tools').pluck('name')
          expect(names).to contain_exactly(
            'list_sensors',
            'get_system_info',
            'get_prices',
            'get_current_values',
            'get_totals',
            'get_ranking',
            'get_series',
            'get_forecast',
          )
        end
      end
    end
  end
end
