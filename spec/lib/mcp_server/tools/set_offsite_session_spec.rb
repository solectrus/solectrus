describe McpServer::Tools::SetOffsiteSession do
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

  # The address keeps its text without Nominatim. The lookup is the one of
  # the form (see ChargingSession::AddressLookup).
  before { allow(Place::Nominatim).to receive(:enabled?).and_return(false) }

  let!(:car) { Car.create!(id: 1, active_from: Date.new(2025, 1, 1)) }
  let(:receipt) do
    { car: 1, started_at: '2026-06-15T10:00:00+02:00', ended_at: '2026-06-15T10:40:00+02:00', kwh: 31.2, cost: 18.4, provider: 'Provider A', address: 'Main Street 15, 12345 Town' }
  end

  it 'needs the admin to allow writing' do
    expect(described_class.available?).to be(false)

    Setting.mcp_write = true
    expect(described_class.available?).to be(true)
  end

  it 'adds a charge, marked as written over MCP' do
    data = answer(**receipt)

    expect(data).to include(result: 'created')
    expect(data[:entry]).to include(car: 1, kwh: 31.2, cost: 18.4, provider: 'Provider A')
    expect(ChargingSession.offsite.sole).to have_attributes(origin: 'mcp', assigned_manually: true, started_at: Time.zone.parse('2026-06-15T08:00:00Z'))
  end

  describe 'the location' do
    it 'keeps the address, but gives it back only while locations are allowed' do
      expect(answer(**receipt)[:entry]).not_to include(:address, :latitude, :longitude)
      expect(ChargingSession.offsite.sole.address).to eq('Main Street 15, 12345 Town')

      Setting.mcp_locations = true
      expect(answer(**receipt)[:entry]).to include(address: 'Main Street 15, 12345 Town')
    end
  end

  context 'with a proposal in the time' do
    let!(:proposal) do
      ChargingSession.insert!({ kind: 'offsite', origin: 'detection', car_id: car.id, started_at: Time.zone.parse('2026-06-15T07:50:00Z'), ended_at: Time.zone.parse('2026-06-15T08:50:00Z'), soc_from: 30, soc_to: 70, kwh: 28 }) # rubocop:disable Rails/SkipsModelValidations
      ChargingSession.sole
    end

    it 'completes and accepts the proposal, and keeps its state of charge' do
      data = answer(**receipt)

      expect(data).to include(result: 'accepted')
      expect(data[:previous]).to include(kwh: 28.0)
      expect(data[:entry]).to include(soc_from: 30.0, soc_to: 70.0, kwh: 31.2)
      expect(proposal.reload).to have_attributes(origin: 'mcp', assigned_manually: true, cost: 18.4)
    end
  end

  context 'with a charge in the time' do
    let!(:entered) do
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Time.zone.parse('2026-06-15T08:00:00Z'), ended_at: Time.zone.parse('2026-06-15T08:40:00Z'), kwh: 30, cost: 18.4, note: 'Trip')
    end

    it 'changes the charge, keeps what the call leaves out, and gives the previous one' do
      data = answer(**receipt.except(:address))

      expect(data).to include(result: 'updated')
      expect(data[:previous]).to include(kwh: 30.0)
      expect(entered.reload).to have_attributes(kwh: 31.2, note: 'Trip', origin: 'mcp')
    end

    it 'changes nothing for the same values' do
      data = answer(car: 1, started_at: '2026-06-15T10:00:00+02:00', kwh: 30, cost: 18.4)

      expect(data).to include(result: 'unchanged')
      expect(entered.reload.origin).to eq('user')
    end
  end

  it 'names what a new charge needs without an id' do
    expect(error(**receipt.except(:car, :started_at))).to eq('Missing car, started_at: they are needed without `id`.')
    expect(ChargingSession.count).to eq(0)
  end

  describe 'the id of an earlier answer' do
    it 'moves a charge of the agent to another time' do
      id = answer(**receipt)[:entry][:id]

      data = answer(**receipt, started_at: '2026-06-15T11:00:00+02:00', ended_at: '2026-06-15T11:40:00+02:00', id:)

      expect(data).to include(result: 'updated')
      expect(ChargingSession.find(id)).to have_attributes(started_at: Time.zone.parse('2026-06-15T09:00:00Z'), origin: 'mcp')
    end

    it 'changes only what the call gives, and keeps the car and the time' do
      id = answer(**receipt)[:entry][:id]

      data = answer(id:, provider: 'Provider B', power_type: 'dc')

      expect(data).to include(result: 'updated')
      expect(ChargingSession.find(id)).to have_attributes(car_id: 1, started_at: Time.zone.parse('2026-06-15T08:00:00Z'), kwh: 31.2, provider: 'Provider B', power_type: 'dc')
    end

    it 'moves a charge to another car, and the previous entry names the old one' do
      Car.create!(id: 2, active_from: Date.new(2025, 1, 1))
      allow(Car).to receive(:configured).and_return(Car.find([1, 2]))
      id = answer(**receipt)[:entry][:id]

      data = answer(id:, car: 2)

      expect(data[:previous]).to include(car: 1)
      expect(data[:entry]).to include(car: 2)
    end

    it 'answers unchanged for an id without anything to change' do
      id = answer(**receipt)[:entry][:id]

      expect(answer(id:)).to include(result: 'unchanged')
    end

    it 'does not change a charge of the admin' do
      entered = ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Time.zone.parse('2026-06-14T08:00:00Z'), kwh: 30, cost: 18.4)

      expect(error(**receipt, id: entered.id)).to include("No entry #{entered.id} to change")
      expect(entered.reload.kwh).to eq(30)
    end
  end

  describe 'the rules of a charge' do
    it 'needs the energy and the cost of a new charge' do
      expect(error(car: 1, started_at: '2026-06-15T10:00:00+02:00')).to include('kwh can\'t be blank', 'cost can\'t be blank')
    end

    it 'rejects a time without its offset' do
      expect(error(**receipt, started_at: '2026-06-15T10:00:00')).to include('Invalid started_at', 'offset')
    end

    it 'rejects an impossible date' do
      expect(error(**receipt, started_at: '2026-02-30T10:00:00+01:00')).to include('Invalid started_at')
    end

    it 'rejects a charge in the future' do
      expect(error(**receipt, started_at: 1.day.from_now.iso8601, ended_at: 2.days.from_now.iso8601)).to include('started_at')
    end

    it 'names the cars for an unknown one' do
      expect(error(**receipt, car: 3)).to include('Unknown car 3', '1 (')
    end
  end
end
