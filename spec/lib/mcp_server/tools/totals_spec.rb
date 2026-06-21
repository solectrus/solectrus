describe McpServer::Tools::Totals do
  before do
    create_summary(date: '2024-06-15', values: [[:house_power, :sum, 12_345]])
  end

  describe '.call' do
    it 'returns totals for a day from the PostgreSQL summaries' do
      response =
        described_class.call(
          server_context: nil,
          timeframe: '2024-06-15',
          sensors: ['house_power'],
        )

      expect(response.error?).to be(false)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      total = data[:totals].find { _1[:name] == 'house_power' }
      expect(total[:value]).to eq(12_345.0)
      expect(total[:unit]).to eq('watt')
    end

    it 'reports an invalid timeframe' do
      response =
        described_class.call(
          server_context: nil,
          timeframe: 'not-a-timeframe',
          sensors: ['house_power'],
        )

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('not a valid timeframe')
    end

    it 'reports an unknown sensor' do
      response =
        described_class.call(
          server_context: nil,
          timeframe: '2024-06-15',
          sensors: ['nonexistent'],
        )

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('Unknown or unconfigured')
    end
  end
end
