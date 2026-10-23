describe CarSelection do
  let(:timeframe) { Timeframe.new('2026-01') }

  before do
    Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_2' => 'car2:odometer'))
    Car.create!(id: 1)
    Car.create!(id: 2, active_from: Date.new(2026, 2, 1))
  end

  after { Sensor::Config.setup(ENV) }

  it 'offers the cars in use in the timeframe' do
    expect(described_class.new(nil, timeframe:).offered.map(&:id)).to eq([1])
    expect(described_class.new(nil, timeframe: nil).offered.map(&:id)).to eq([1, 2])
  end

  it 'selects an offered car' do
    selection = described_class.new('1', timeframe:)

    expect(selection.car.id).to eq(1)
    expect(selection.filter).to eq(1)
    expect(selection.to_param).to eq('1')
  end

  it 'selects "all" without a parameter' do
    selection = described_class.new(nil, timeframe:)

    expect(selection.car).to be_nil
    expect(selection.cars.map(&:id)).to eq([1])
    expect(selection).to be_valid
  end

  it 'is no selection for a car that the timeframe does not offer' do
    [described_class.new('2', timeframe:), described_class.new('x', timeframe:)].each do |selection|
      expect(selection.to_param).to be_nil
      expect(selection).not_to be_valid
    end
  end

  it 'selects no guest without the guests' do
    expect(described_class.new('guest', timeframe:)).not_to be_valid
  end

  describe 'with the guests' do
    def selection(param = 'guest') = described_class.new(param, timeframe:, guest: true)

    it 'offers no guests before a guest session' do
      expect(selection).not_to be_guest_offered
      expect(selection).not_to be_valid
    end

    context 'with a guest session' do
      before do
        start = Time.zone.local(2025, 6, 1, 10)
        ChargingSession.create!(kind: :wallbox, origin: :detection, guest: true, started_at: start, ended_at: start + 1.hour, kwh: 7)
      end

      # A timeframe without a guest session keeps the selection
      it 'selects the guests without a car' do
        expect(selection).to be_guest
        expect(selection).to be_valid
        expect([selection.car, selection.cars, selection.to_param]).to eq([nil, [], 'guest'])
      end

      it 'selects no guests on another page' do
        expect(described_class.new('guest', timeframe:)).not_to be_guest_offered
        expect(selection(nil)).not_to be_guest
      end
    end
  end
end
