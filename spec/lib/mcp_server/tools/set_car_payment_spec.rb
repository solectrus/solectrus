describe McpServer::Tools::SetCarPayment do
  def call(**args)
    response = described_class.call(server_context: nil, **args)
    text = response.content.first[:text]

    response.error? ? [true, text] : [false, JSON.parse(text, symbolize_names: true)]
  end

  let!(:car) { Car.create!(id: 1, active_from: Date.new(2025, 1, 1)) }
  let(:bill) { { car: 1, date: '2026-03-15', category: 'insurance', amount: 420, reference: 'POL-7' } }

  describe '.available?' do
    before { Setting.mcp_write = true }

    it 'needs the comparison, like the page of the payments' do
      allow(Car::Comparison).to receive(:available?).and_return(false)
      expect(described_class.available?).to be(false)

      allow(Car::Comparison).to receive(:available?).and_return(true)
      expect(described_class.available?).to be(true)
    end
  end

  it 'adds a payment of the car' do
    _, data = call(**bill)

    expect(data).to include(result: 'created')
    expect(data[:entry]).to include(car: 1, amount: 420.0, reference: 'POL-7')
    expect(car.payments.sole).to have_attributes(category: 'insurance', origin: 'mcp')
  end

  it 'counts an equal payment of another car as another payment' do
    other = Car.create!(id: 2, active_from: Date.new(2025, 1, 1))
    allow(Car).to receive(:configured).and_return([car, other])
    Car::Payment.create!(car_id: 2, date: '2026-03-15', category: 'insurance', amount: 420)

    _, data = call(**bill.except(:reference))

    expect(data).to include(result: 'created')
  end

  it 'reports the rules of the car' do
    car.update!(active_until: Date.new(2025, 12, 31))

    error, text = call(**bill)

    expect(error).to be(true)
    expect(text).to start_with('Nothing was saved: date')
  end

  it 'names the cars for an unknown one' do
    error, text = call(**bill, car: 3)

    expect(error).to be(true)
    expect(text).to include('Unknown car 3', '1 (')
    expect(Car::Payment.count).to eq(0)
  end
end
