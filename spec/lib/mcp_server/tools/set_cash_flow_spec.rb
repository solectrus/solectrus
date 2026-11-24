describe McpServer::Tools::SetCashFlow do
  def call(**args)
    response = described_class.call(server_context: nil, **args)
    text = response.content.first[:text]

    response.error? ? [true, text] : [false, JSON.parse(text, symbolize_names: true)]
  end

  it 'needs the admin to allow writing' do
    expect(described_class.available?).to be(false)

    Setting.mcp_write = true
    expect(described_class.available?).to be(true)
  end

  it 'adds a cash flow with its sign, as get_cash_flows lists it' do
    _, data = call(date: '2026-03-15', category: 'repair', amount: -1200, note: 'New inverter', reference: 'R-1')

    expect(data).to include(result: 'created')
    expect(data[:entry]).to eq(id: CashFlow.sole.id, date: '2026-03-15', category: 'repair', amount: -1200.0, note: 'New inverter', reference: 'R-1', origin: 'mcp')
    expect(CashFlow.sole).to have_attributes(origin: 'mcp', reference: 'R-1')
  end

  it 'reports the sign that the category needs' do
    error, text = call(date: '2026-03-15', category: 'repair', amount: 1200, note: 'New inverter')

    expect(error).to be(true)
    expect(text).to start_with('Nothing was saved: amount')
    expect(CashFlow.count).to eq(0)
  end
end
