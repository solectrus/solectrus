describe ChargingSession::Detection::Persistence do
  subject(:persistence) { described_class.new(assignment) }

  let(:day) { Date.new(2026, 6, 10) }
  let(:car) { Car.create!(id: 1) }
  let(:other_car) { Car.create!(id: 2) }
  let(:assignment) { ChargingSession::Detection::CarAssignment.new([car, other_car], curves: ->(*) { [] }) }

  def at(hour, min = 0) = day.in_time_zone.change(hour:, min:)

  def detected(from, to, kwh: 10, car_id: nil)
    ChargingSession::Detection::Session.new(started_at: from, ended_at: to, kwh:, kwh_grid: nil, cost: 3, cost_grid: nil, car_id:)
  end

  def stored(from, to, **)
    ChargingSession.create!(kind: :wallbox, started_at: from, ended_at: to, kwh: 5, **)
  end

  it 'updates the energy of an existing session and keeps its car and its note' do
    session = stored(at(8), at(9), car:, note: 'Trip')

    persistence.call(day => [detected(at(8), at(10), kwh: 12, car_id: 2)])

    expect(session.reload).to have_attributes(kwh: 12, ended_at: at(10), car_id: 1, note: 'Trip')
  end

  it 'keeps a guest mark' do
    session = stored(at(8), at(9), guest: true)

    persistence.call(day => [detected(at(8), at(9), car_id: 1)])

    expect(session.reload).to have_attributes(guest: true, car_id: nil)
  end

  it 'gives an open session the car of the rules' do
    session = stored(at(8), at(9))

    persistence.call(day => [detected(at(8), at(9), car_id: 2)])

    expect(session.reload.car_id).to eq(2)
  end

  it 'takes the car from a session outside the period of the car' do
    session = stored(at(8), at(9), car:)
    car.update_columns(active_until: day - 1) # rubocop:disable Rails/SkipsModelValidations

    persistence.call(day => [detected(at(8), at(9))])

    expect(session.reload.car_id).to be_nil
  end

  it 'gives the changes of a removed session to the new session that overlaps it most' do
    stored(at(8), at(9), guest: true, note: 'Visit')

    persistence.call(day => [detected(at(7, 55), at(9), car_id: 1), detected(at(12), at(13), car_id: 1)])

    expect(ChargingSession.order(:started_at).map { [it.started_at, it.guest, it.note] }).to eq(
      [[at(7, 55), true, 'Visit'], [at(12), false, nil]],
    )
  end

  it 'keeps the guest mark over a car when two removed sessions merge' do
    stored(at(8), at(9), guest: true)
    stored(at(9, 30), at(10, 30), car: other_car)

    persistence.call(day => [detected(at(7, 55), at(10, 30), car_id: 1)])

    expect(ChargingSession.sole).to have_attributes(guest: true, car_id: nil)
  end

  it 'gives the changes of a session without a length to the session that holds its start' do
    ChargingSession.create!(kind: :wallbox, started_at: at(8, 30), ended_at: at(8, 30), kwh: 5, guest: true)

    persistence.call(day => [detected(at(8), at(9), car_id: 1)])

    expect(ChargingSession.sole).to have_attributes(started_at: at(8), guest: true)
  end

  it 'removes the sessions of the day that the new result does not contain' do
    stored(at(18), at(19))

    persistence.call(day => [])

    expect(ChargingSession.count).to eq(0)
  end

  it 'never touches an offsite session' do
    ChargingSession.create!(kind: :offsite, car:, started_at: at(18), kwh: 5, cost: 2)

    persistence.call(day => [])

    expect(ChargingSession.offsite.count).to eq(1)
  end
end
