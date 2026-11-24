describe McpServer::Tools::CarPayments do
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

  let!(:car) { Car.create!(id: 1, active_from: Date.new(2020, 1, 1)) }

  before do
    allow(Car::Comparison).to receive(:available?).and_return(true)

    car.payments.create!(category: :insurance, date: Date.new(2026, 3, 1), amount: 480, note: 'Insurance')
    car.payments.create!(category: :ghg_quota, date: Date.new(2026, 4, 15), amount: 85, reference: 'Q-1', origin: :mcp)
    car.payments.create!(category: :insurance, date: Date.new(2025, 3, 1), amount: 450)
  end

  it 'needs the list of the payments of a car, which needs fuel prices' do
    expect(described_class.available?).to be(true)

    allow(Car::Comparison).to receive(:available?).and_return(false)
    expect(described_class.available?).to be(false)
  end

  it 'lists the payments newest first, with an income positive in the sums' do
    data = answer

    expect(data).to include(currency: Rails.configuration.x.currency, total_count: 3, sum: -845.0, sum_by_category: { insurance: -930.0, ghg_quota: 85.0 })
    expect(data[:payments].first).to eq(
      id: Car::Payment.find_by(reference: 'Q-1').id,
      car: 1,
      date: '2026-04-15',
      category: 'ghg_quota',
      amount: 85.0,
      note: nil,
      reference: 'Q-1',
      origin: 'mcp',
    )
  end

  it 'filters by dates and counts all matching payments while it limits the list' do
    data = answer(from: '2026-01-01', limit: 1)

    expect(data).to include(total_count: 2, sum: -395.0)
    expect(data[:payments].pluck(:date)).to eq(%w[2026-04-15])
  end

  it 'filters by category, and names the categories for an unknown one' do
    expect(answer(category: 'insurance')).to include(total_count: 2, sum: -930.0)

    error, text = call(category: 'repair')
    expect(error).to be(true)
    expect(text).to start_with('Unknown category "repair". Available: purchase,')
  end
end
