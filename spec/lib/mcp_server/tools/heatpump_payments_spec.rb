describe McpServer::Tools::HeatpumpPayments do
  def answer(**args)
    response = described_class.call(server_context: nil, **args)
    expect(response.error?).to be(false), "Unexpected error: #{response.content.first[:text]}"

    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  it 'needs the settings of the heat pump' do
    allow(Heatpump::Comparison).to receive(:settings?).and_return(false)
    expect(described_class.available?).to be(false)

    allow(Heatpump::Comparison).to receive(:settings?).and_return(true)
    expect(described_class.available?).to be(true)
  end

  it 'lists the payments of the heat pump, without a car' do
    Heatpump::Payment.create!(category: :maintenance, date: Date.new(2026, 5, 1), amount: 189.5)
    Heatpump::Payment.create!(category: :subsidy, date: Date.new(2026, 6, 1), amount: 500)

    data = answer

    expect(data).to include(total_count: 2, sum: 310.5, sum_by_category: { maintenance: -189.5, subsidy: 500.0 })
    expect(data[:payments].pluck(:category)).to eq(%w[subsidy maintenance])
    expect(data[:payments].first).not_to include(:car)
  end
end
