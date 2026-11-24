# The heat pump stands for the three tools that write a payment: they find a
# payment again in the same way (see McpServer::Tools::Recording)
describe McpServer::Tools::SetHeatpumpPayment do
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

  let(:bill) { { date: '2026-03-15', category: 'maintenance', amount: 189.5, note: 'Annual service' } }

  # The description explains the categories like the hint of the form, so it
  # names each one by hand
  it 'names each category in the description of the category' do
    description = described_class.input_schema.to_h.dig(:properties, :category, :description)

    expect(description).to include(*Heatpump::Payment.categories.keys)
    expect(description).to include('maintenance (repairs too)')
  end

  describe '.available?' do
    before { allow(Heatpump::Comparison).to receive(:settings?).and_return(true) }

    it 'needs the admin to allow writing' do
      expect(described_class.available?).to be(false)

      Setting.mcp_write = true
      expect(described_class.available?).to be(true)
    end

    it 'needs the settings of the heat pump' do
      Setting.mcp_write = true
      allow(Heatpump::Comparison).to receive(:settings?).and_return(false)

      expect(described_class.available?).to be(false)
    end
  end

  it 'adds a payment, marked as written over MCP' do
    data = answer(**bill, reference: 'INV-1')

    expect(data).to include(result: 'created')
    expect(data[:entry]).to eq(id: Heatpump::Payment.sole.id, date: '2026-03-15', category: 'maintenance', amount: 189.5, note: 'Annual service', reference: 'INV-1', origin: 'mcp')
    expect(Heatpump::Payment.sole).to have_attributes(amount: 189.5, origin: 'mcp', reference: 'INV-1')
  end

  context 'with the number of a document' do
    let!(:payment) { Heatpump::Payment.create!(date: '2026-03-15', category: 'maintenance', amount: 180, reference: 'INV-1', note: 'Service') }

    it 'changes the payment of that document, and gives the previous one' do
      data = answer(**bill.except(:note), amount: 189.5, reference: 'INV-1')

      expect(data).to include(result: 'updated')
      expect(data[:previous]).to include(amount: 180.0)
      expect(payment.reload).to have_attributes(amount: 189.5, note: 'Service', origin: 'mcp')
    end

    it 'changes nothing for the same values' do
      data = answer(date: '2026-03-15', category: 'maintenance', amount: 180, reference: 'INV-1')

      expect(data).to include(result: 'unchanged')
      expect(payment.reload.origin).to eq('user')
    end

    it 'adds the payment of another document, also with the same values' do
      data = answer(date: '2026-03-15', category: 'maintenance', amount: 180, reference: 'INV-2')

      expect(data).to include(result: 'created')
      expect(Heatpump::Payment.count).to eq(2)
    end
  end

  context 'with an equal payment without a number' do
    let!(:payment) { Heatpump::Payment.create!(date: '2026-03-15', category: 'maintenance', amount: 189.5) }

    it 'adds nothing without a number, and names the payment' do
      data = answer(**bill)

      expect(data).to include(result: 'exists')
      expect(data[:hint]).to include('reference')
      expect(Heatpump::Payment.sole).to eq(payment)
    end

    it 'adds nothing with a new number either, and leaves the payment alone' do
      data = answer(**bill, reference: 'INV-1')

      expect(data).to include(result: 'exists')
      expect(payment.reload).to have_attributes(reference: nil, origin: 'user')
    end
  end

  it 'adds a payment that differs in its amount' do
    Heatpump::Payment.create!(date: '2026-03-15', category: 'maintenance', amount: 100)

    expect(answer(**bill)).to include(result: 'created')
  end

  # An agent corrects its own entry, also the values that find it
  it 'names what a new payment needs without an id' do
    expect(error(**bill.except(:amount))).to eq('Missing amount: it is needed without `id`.')
    expect(Heatpump::Payment.count).to eq(0)
  end

  describe 'the id of an earlier answer' do
    it 'changes an entry of the agent, also its category' do
      id = answer(**bill, category: 'other_expense')[:entry][:id]

      data = answer(**bill, id:)

      expect(data).to include(result: 'updated')
      expect(data[:previous]).to include(id:, category: 'other_expense')
      expect(Heatpump::Payment.sole).to have_attributes(id:, category: 'maintenance', origin: 'mcp')
    end

    it 'changes only what the call gives, and keeps the rest' do
      id = answer(**bill)[:entry][:id]

      data = answer(id:, note: 'Annual service, parts included')

      expect(data).to include(result: 'updated')
      expect(Heatpump::Payment.sole).to have_attributes(date: Date.new(2026, 3, 15), category: 'maintenance', amount: 189.5, note: 'Annual service, parts included')
    end

    it 'answers unchanged for an id without anything to change' do
      id = answer(**bill)[:entry][:id]

      expect(answer(id:)).to include(result: 'unchanged')
    end

    it 'does not change an entry of the admin' do
      payment = Heatpump::Payment.create!(date: '2026-03-15', category: 'other_expense', amount: 189.5)

      expect(error(**bill, id: payment.id)).to include("No entry #{payment.id} to change")
      expect(payment.reload.category).to eq('other_expense')
    end
  end

  describe 'the rules of a payment' do
    it 'rejects a negative income' do
      expect(error(date: '2026-03-15', category: 'subsidy', amount: -500)).to include('amount must be greater than 0')
    end

    it 'rejects a date that is not ISO 8601' do
      expect(error(**bill, date: '15.03.2026')).to include('Invalid date')
    end
  end
end
