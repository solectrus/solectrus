describe McpServer::Tools::CashFlows do
  before do
    CashFlow.create!(date: Date.new(2021, 3, 1), amount: -12_000, category: 'investment', note: 'PV system')
    CashFlow.create!(date: Date.new(2021, 6, 1), amount: 1_500, category: 'subsidy', note: 'Grant')
    CashFlow.create!(date: Date.new(2023, 4, 15), amount: -180.55, category: 'operating_cost', note: 'Insurance')
    CashFlow.create!(date: Date.new(2024, 2, 1), amount: -320, category: 'repair', note: 'Inverter fan')
  end

  def data_from(response)
    expect(response.error?).to be(false)
    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  describe '.call' do
    it 'returns every entry, newest first' do
      data = data_from(described_class.call(server_context: nil))

      expect(data[:currency]).to eq(Rails.configuration.x.currency)
      expect(data[:total_count]).to eq(4)
      expect(data[:categories]).to be_nil
      expect(data[:entries].pluck(:date)).to eq(
        %w[2024-02-01 2023-04-15 2021-06-01 2021-03-01],
      )
      expect(data[:entries].first).to include(
        category: 'repair',
        amount: -320.0,
        note: 'Inverter fan',
      )
    end

    it 'orders ascending on request' do
      data = data_from(described_class.call(server_context: nil, order: 'asc'))

      expect(data[:order]).to eq('asc')
      expect(data[:entries].first[:date]).to eq('2021-03-01')
    end

    it 'sums the whole register and each category' do
      data = data_from(described_class.call(server_context: nil))

      expect(data[:sum]).to eq(-11_000.55)
      expect(data[:sum_by_category]).to eq(
        investment: -12_000.0,
        subsidy: 1_500.0,
        operating_cost: -180.55,
        repair: -320.0,
      )
    end

    it 'filters by category' do
      data =
        data_from(
          described_class.call(server_context: nil, categories: %w[operating_cost repair]),
        )

      expect(data[:categories]).to eq(%w[operating_cost repair])
      expect(data[:total_count]).to eq(2)
      expect(data[:entries].pluck(:category)).to contain_exactly('operating_cost', 'repair')
      expect(data[:sum]).to eq(-500.55)
    end

    it 'filters by date range' do
      data =
        data_from(described_class.call(server_context: nil, from: '2021-06-01', to: '2023-12-31'))

      expect(data).to include(from: '2021-06-01', to: '2023-12-31')
      expect(data[:entries].pluck(:date)).to eq(%w[2023-04-15 2021-06-01])
    end

    # The totals answer the question a limited list cannot: with `limit` cutting
    # the entries, summing what came back would be wrong by whatever was cut.
    it 'keeps the sums over all matching entries while limiting the list' do
      data = data_from(described_class.call(server_context: nil, limit: 1))

      expect(data[:limit]).to eq(1)
      expect(data[:entries].size).to eq(1)
      expect(data[:total_count]).to eq(4)
      expect(data[:sum]).to eq(-11_000.55)
    end

    it 'clamps the limit into 1..200' do
      data = data_from(described_class.call(server_context: nil, limit: 5_000))

      expect(data[:limit]).to eq(described_class::MAX_ENTRIES)
    end

    it 'answers an empty register with an empty list' do
      CashFlow.delete_all

      data = data_from(described_class.call(server_context: nil))

      expect(data[:total_count]).to eq(0)
      expect(data[:entries]).to eq([])
      expect(data[:sum]).to eq(0)
      expect(data[:sum_by_category]).to eq({})
    end

    it 'rejects an unknown category' do
      response = described_class.call(server_context: nil, categories: %w[investment lottery])

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('lottery', 'investment')
    end

    it 'rejects a malformed date' do
      response = described_class.call(server_context: nil, from: '2021-02-30')

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('Invalid from')
    end

    # An inverted range matches nothing, and "no entries" is an answer a client
    # believes - so the swapped dates are named instead.
    it 'rejects an inverted range and names the fix' do
      response = described_class.call(server_context: nil, from: '2024-01-01', to: '2021-01-01')

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('from=2021-01-01, to=2024-01-01')
    end
  end
end
