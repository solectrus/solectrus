describe McpServer::ResultCompliance do
  describe '.apply' do
    def apply(message, method: 'ping')
      JSON.parse(described_class.apply(message.to_json, method:))
    end

    it 'marks a result as complete' do
      result = apply({ jsonrpc: '2.0', id: 1, result: { pong: true } })

      expect(result['result']).to eq('resultType' => 'complete', 'pong' => true)
    end

    it 'keeps a resultType the server already set' do
      result =
        apply(
          { jsonrpc: '2.0', id: 1, result: { resultType: 'input_required' } },
        )

      expect(result.dig('result', 'resultType')).to eq('input_required')
    end

    it 'leaves an error response alone' do
      message = {
        jsonrpc: '2.0',
        id: 1,
        error: {
          code: -32_601,
          message: 'Method not found',
        },
      }

      expect(apply(message)).to eq(message.deep_stringify_keys)
    end

    # A 202 (notification acknowledged) carries no body at all.
    it 'passes an empty body through' do
      expect(described_class.apply('', method: 'ping')).to eq('')
    end

    it 'passes a body it cannot parse through' do
      expect(described_class.apply('not json', method: 'ping')).to eq(
        'not json',
      )
    end

    context 'with a cacheable result' do
      # The one cacheable result the gem leaves without hints.
      it 'adds the cache hints to server/discover' do
        result =
          apply(
            { jsonrpc: '2.0', id: 1, result: { supportedVersions: [] } },
            method: 'server/discover',
          )

        expect(result['result']).to include(
          'ttlMs' => 300_000,
          'cacheScope' => 'private',
        )
      end

      it 'keeps hints the gem already set' do
        result =
          apply(
            {
              jsonrpc: '2.0',
              id: 1,
              result: {
                tools: [],
                ttlMs: 60_000,
                cacheScope: 'public',
              },
            },
            method: 'tools/list',
          )

        expect(result['result']).to include(
          'ttlMs' => 60_000,
          'cacheScope' => 'public',
        )
      end
    end

    # Only a cacheable result may carry them; on anything else they would be
    # members the schema does not know.
    it 'adds no cache hints to an ordinary result' do
      result = apply({ jsonrpc: '2.0', id: 1, result: { pong: true } })

      expect(result['result'].keys).to contain_exactly('resultType', 'pong')
    end
  end
end
