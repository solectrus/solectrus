describe ChargingSession::Spot do
  let(:car) { Car.create!(id: 1, name: 'Trabant') }
  let(:scope) { ChargingSession.listed('offsite') }

  def session(latitude, longitude, kwh: 10, **)
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Time.current, latitude:, longitude:, kwh:, cost: 1, **)
  end

  describe '.cells' do
    it 'joins the sessions at the same position, to about 100 m, the most energy first' do
      session(48.1, 11.5, kwh: 5)
      session(50.9001, 14.1001)
      session(50.9003, 14.1003, kwh: 20)

      cells = described_class.cells(scope)

      expect(cells.map { [it.latitude, it.longitude, it.kwh, it.count] }).to eq([[50.9002, 14.1002, 30, 2], [48.1, 11.5, 5, 1]])
    end

    it 'knows the session of a cell with one session alone' do
      single = session(48.1, 11.5)
      session(50.9001, 14.1001)
      session(50.9003, 14.1003)

      expect(described_class.cells(scope).map(&:session_id)).to eq([nil, single.id])
    end

    it 'counts the sessions without a position in a cell without an id' do
      session(nil, nil)

      expect(described_class.cells(scope).sole).to have_attributes(id: nil, count: 1)
    end
  end

  describe '.find' do
    it 'gives the sessions of the cell' do
      near = session(50.9001, 14.1001)
      session(50.91, 14.1)
      id = described_class.cells(scope).min_by(&:latitude).id

      expect(described_class.find(scope, id).sessions).to eq([near])
    end

    it 'gives nil for a cell without a session' do
      expect(described_class.find(scope, 1)).to be_nil
    end
  end

  describe '#name' do
    def spot(*addresses)
      described_class.new(sessions: addresses.map { ChargingSession.new(latitude: 50.9, longitude: 14.1, address: it) })
    end

    it 'is the address that most of its sessions have' do
      expect(spot('Main Street 1', 'Main Street 1', 'Main St. 1').name).to eq('Main Street 1')
    end

    it 'is nil without an address, a provider and a note' do
      expect(spot(nil).name).to be_nil
    end
  end

  describe '#name_lines' do
    it 'splits the address of the name' do
      spot = described_class.new(sessions: [ChargingSession.new(address: 'DE-12345 Town, Main Street 15')])

      expect(spot.name_lines).to eq(['DE-12345 Town', 'Main Street 15'])
    end

    it 'keeps a name from the provider in one line' do
      spot = described_class.new(sessions: [ChargingSession.new(provider: 'Ionity, A3')])

      expect(spot.name_lines).to eq(['Ionity, A3'])
    end

    it 'is empty without a name' do
      expect(described_class.new(sessions: [ChargingSession.new]).name_lines).to eq([])
    end
  end

  describe '#costed?' do
    it 'is false while a session has no cost' do
      expect(described_class.new(sessions: [ChargingSession.new(cost: 1), ChargingSession.new]).costed?).to be(false)
    end
  end
end
