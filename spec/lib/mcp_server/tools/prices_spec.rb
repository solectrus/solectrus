describe McpServer::Tools::Prices do
  before do
    Price.create!(name: 'electricity', starts_at: '2024-01-01', value: 0.30)
    Price.create!(
      name: 'electricity',
      starts_at: '2025-01-01',
      value: 0.35,
      note: 'New contract',
    )
    Price.create!(name: 'feed_in', starts_at: '2024-01-01', value: 0.08)
  end

  describe '.call' do
    it 'returns the price effective on the given date plus history' do
      response = described_class.call(server_context: nil, date: '2025-06-15')

      expect(response.error?).to be(false)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)

      electricity = data[:prices].find { _1[:name] == 'electricity' }
      expect(electricity[:current]).to eq(0.35)
      expect(electricity[:unit]).to eq("#{Rails.configuration.x.currency}/kWh")
      expect(electricity[:history].pluck(:value)).to include(0.35, 0.30)

      latest = electricity[:history].find { _1[:starts_at] == '2025-01-01' }
      expect(latest[:note]).to eq('New contract')

      feed_in = data[:prices].find { _1[:name] == 'feed_in' }
      expect(feed_in[:current]).to eq(0.08)
    end

    it 'sorts the history by value and limits it' do
      response =
        described_class.call(
          server_context: nil,
          sort: 'value',
          order: 'desc',
          limit: 1,
        )

      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      expect(data).to include(sort: 'value', order: 'desc', limit: 1)

      electricity = data[:prices].find { _1[:name] == 'electricity' }
      expect(electricity[:history].size).to eq(1)
      expect(electricity[:history].first[:value]).to eq(0.35)
      # current is still derived from the full history, not the limited slice
      expect(electricity[:current]).to eq(0.35)
    end

    it 'clamps the limit into 1..100' do
      response = described_class.call(server_context: nil, limit: 0)

      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      expect(data[:limit]).to eq(1)
      expect(data[:prices].first[:history].size).to eq(1)
    end

    it 'defaults to today when no date is given' do
      response = described_class.call(server_context: nil)

      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      expect(data[:date]).to eq(Date.current.iso8601)
    end

    it 'reports an invalid date' do
      response = described_class.call(server_context: nil, date: 'not-a-date')

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('Invalid date')
    end
  end
end
