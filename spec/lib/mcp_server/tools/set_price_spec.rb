describe McpServer::Tools::SetPrice do
  def call(**args)
    response = described_class.call(server_context: nil, **args)
    text = response.content.first[:text]

    response.error? ? [true, text] : [false, JSON.parse(text, symbolize_names: true)]
  end

  def answer(**args)
    error, data = call(**args)
    expect(error).to be(false), "Unexpected error: #{data}"

    data
  end

  def error(**args)
    error, text = call(**args)
    expect(error).to be(true), "Expected an error, got #{text}"

    text
  end

  describe '.available?' do
    it 'needs the admin to allow writing' do
      expect(described_class.available?).to be(false)

      Setting.mcp_write = true
      expect(described_class.available?).to be(true)
    end
  end

  it 'declares that it writes, and that it can overwrite' do
    expect(described_class.annotations.to_h).to include(
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: true,
    )
  end

  context 'without an entry on the date' do
    it 'adds the price, marked as written over MCP' do
      data = answer(name: 'electricity', starts_at: '2026-01-01', value: 0.3125, base_fee_per_month: 12.5, note: 'Tariff A')

      expect(data).to include(result: 'created')
      expect(data[:entry]).to eq(name: 'electricity', id: Price.find_by(starts_at: '2026-01-01').id, starts_at: '2026-01-01', value: 0.3125, base_fee_per_month: 12.5, note: 'Tariff A', origin: 'mcp')
      expect(data).not_to include(:previous)

      price = Price.find_by!(name: 'electricity', starts_at: '2026-01-01')
      expect(price).to have_attributes(amount_per_kwh: 0.3125, amount_per_month: 12.5, origin: 'mcp')
    end

    it 'needs a value' do
      expect(error(name: 'feed_in', starts_at: '2026-01-01')).to include('value can\'t be blank')
      expect(Price.where(starts_at: '2026-01-01')).to be_empty
    end
  end

  context 'with an entry of the admin on the date' do
    let!(:price) do
      Price.create!(name: 'electricity', starts_at: '2026-01-01', amount_per_kwh: 0.30, amount_per_month: 10, note: 'Tariff A')
    end

    it 'changes the given values, keeps the others, and gives the previous entry' do
      data = answer(name: 'electricity', starts_at: '2026-01-01', value: 0.32)

      expect(data).to include(result: 'updated')
      expect(data[:entry]).to include(value: 0.32, base_fee_per_month: 10.0, note: 'Tariff A')
      expect(data[:previous]).to include(value: 0.3)
      expect(price.reload).to have_attributes(amount_per_kwh: 0.32, amount_per_month: 10, origin: 'mcp')
    end

    it 'clears a value given as null' do
      answer(name: 'electricity', starts_at: '2026-01-01', base_fee_per_month: nil, note: nil)

      expect(price.reload).to have_attributes(amount_per_month: nil, note: nil)
    end

    it 'changes nothing for the same values, and keeps the entry the admin\'s' do
      data = answer(name: 'electricity', starts_at: '2026-01-01', value: 0.30, note: 'Tariff A')

      expect(data).to include(result: 'unchanged')
      expect(data).not_to include(:previous)
      expect(price.reload.origin).to eq('user')
    end

    it 'leaves the entry of the other tariff alone' do
      data = answer(name: 'feed_in', starts_at: '2026-01-01', value: 0.08)

      expect(data).to include(result: 'created')
      expect(price.reload.amount_per_kwh).to eq(0.30)
    end
  end

  it 'names what a new price needs without an id' do
    expect(error(name: 'electricity', value: 0.3)).to eq('Missing starts_at: it is needed without `id`.')
  end

  describe 'the id of an earlier answer' do
    it 'moves an entry of the agent to another start' do
      id = answer(name: 'electricity', starts_at: '2026-01-01', value: 0.3)[:entry][:id]

      data = answer(name: 'electricity', starts_at: '2026-02-01', value: 0.3, id:)

      expect(data).to include(result: 'updated')
      expect(data[:entry]).to include(id:)
      expect(Price.find(id)).to have_attributes(starts_at: Date.new(2026, 2, 1), origin: 'mcp')
      expect(Price.where(starts_at: '2026-01-01')).to be_empty
    end

    it 'changes only what the call gives, and keeps the start' do
      id = answer(name: 'electricity', starts_at: '2026-01-01', value: 0.3)[:entry][:id]

      data = answer(id:, value: 0.32)

      expect(data).to include(result: 'updated')
      expect(data[:entry]).to include(name: 'electricity')
      expect(Price.find(id)).to have_attributes(starts_at: Date.new(2026, 1, 1), amount_per_kwh: 0.32)
    end

    it 'does not change an entry of the admin' do
      price = Price.create!(name: 'electricity', starts_at: '2026-01-01', amount_per_kwh: 0.3)

      expect(error(name: 'electricity', starts_at: '2026-02-01', value: 0.3, id: price.id)).to include("No entry #{price.id} to change")
      expect(price.reload.starts_at).to eq(Date.new(2026, 1, 1))
    end
  end

  describe 'the rules of a price' do
    it 'rejects a negative value' do
      expect(error(name: 'electricity', starts_at: '2026-01-01', value: -0.1)).to include('value must be greater than or equal to 0')
    end

    it 'rejects a base fee for the feed-in' do
      expect(error(name: 'feed_in', starts_at: '2026-01-01', value: 0.08, base_fee_per_month: 5)).to include('base_fee_per_month must be blank')
    end

    it 'rejects an unknown name' do
      expect(error(name: 'gas', starts_at: '2026-01-01', value: 0.1)).to include('Invalid name "gas"')
    end

    it 'rejects a date that is not ISO 8601' do
      expect(error(name: 'electricity', starts_at: 'next Monday', value: 0.3)).to include('Invalid starts_at')
    end
  end
end
