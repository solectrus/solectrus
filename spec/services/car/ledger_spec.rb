describe Car::Ledger do
  subject(:ledger) { described_class.new([car], january) }

  let(:car) { Car.create!(id: 1) }
  let(:other_car) { Car.create!(id: 2) }
  let(:january) { Date.new(2026, 1, 1)..Date.new(2026, 1, 31) }

  def wallbox(day, kwh:, car: nil, guest: false, hour: 12)
    start = Time.zone.local(2026, 1, day, hour)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car:, guest:, started_at: start, ended_at: start + 1.hour, kwh:)
  end

  before do
    wallbox(10, kwh: 10, car:)
    wallbox(10, kwh: 1, car:, hour: 18)
    wallbox(11, kwh: 20, car: other_car)
    wallbox(12, kwh: 5, guest: true)
    wallbox(13, kwh: 7)
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Time.zone.local(2026, 1, 14, 12), kwh: 8, cost: 4)

    Summary.create!(date: Date.new(2026, 1, 10))
    SummaryValue.create!(date: Date.new(2026, 1, 10), field: 'car_odometer_1', aggregation: 'sum', value: 42)
  end

  it 'sums the sessions of the cars, of each kind or of one' do
    expect(ledger.sessions(january).kwh).to eq(19.0)
    expect(ledger.sessions(january, kind: :wallbox).kwh).to eq(11.0)
    expect(ledger.sessions(january, kind: :offsite).kwh).to eq(8.0)
  end

  it 'sums the sessions of the given dates' do
    expect(ledger.sessions(Date.new(2026, 1, 11)..Date.new(2026, 1, 31)).kwh).to eq(8.0)
  end

  it 'sums the sessions of a car on a day' do
    expect(ledger.daily_sessions(car, Date.new(2026, 1, 10)).count).to eq(2)
    expect(ledger.daily_sessions(car, Date.new(2026, 1, 9))).to eq(ChargingSession::Sums.empty)
  end

  it 'sums the guest sessions and the sessions that are not assigned' do
    expect(ledger.guest_sessions(january).kwh).to eq(5.0)
    expect(ledger.unassigned_sessions(january).kwh).to eq(7.0)
  end

  it 'reads the distance of each day' do
    expect(ledger.distance(january)).to eq(42)
    expect(ledger.daily_distance(car, Date.new(2026, 1, 11))).to eq(0)
    expect(ledger.distance(Date.new(2026, 1, 11)..Date.new(2026, 1, 31))).to be_nil
  end

  it 'reads the sessions and the summaries in one query each' do
    queries = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:name] }, 'sql.active_record') do
      ledger.sessions(january)
      ledger.guest_sessions(january)
      ledger.daily_sessions(car, Date.new(2026, 1, 10))
      ledger.distance(january)
    end

    expect(queries).to eq(['ChargingSession Pluck', 'SummaryValue Pluck'])
  end
end
