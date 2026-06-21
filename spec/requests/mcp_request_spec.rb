describe 'MCP' do
  def post_mcp(payload, token: Setting.mcp_token)
    headers = {
      'CONTENT_TYPE' => 'application/json',
      'ACCEPT' => 'application/json, text/event-stream',
    }
    headers['Authorization'] = "Bearer #{token}" if token

    post '/mcp', params: payload.to_json, headers:
  end

  let(:tools_list) do
    { jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} }
  end

  describe 'POST /mcp' do
    context 'when MCP is disabled (default)' do
      it 'returns http not found, even with a token' do
        post_mcp(tools_list, token: 'whatever')

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when MCP is enabled but the operator is not a sponsor' do
      before do
        Setting.mcp_enabled = true
        Setting.mcp_token = 'secret-token'
        allow(ApplicationPolicy).to receive(:mcp?).and_return(false)
      end

      it 'returns http not found, even with the correct token' do
        post_mcp(tools_list)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when MCP is enabled' do
      before do
        Setting.mcp_enabled = true
        Setting.mcp_token = 'secret-token'
        allow(ApplicationPolicy).to receive(:mcp?).and_return(true)
      end

      context 'without a token' do
        it 'returns http unauthorized' do
          post_mcp(tools_list, token: nil)

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'with a wrong token' do
        it 'returns http unauthorized' do
          post_mcp(tools_list, token: 'wrong-token')

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'with the correct token' do
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
          )
        end
      end
    end
  end
end
