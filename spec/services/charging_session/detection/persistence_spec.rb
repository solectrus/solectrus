describe ChargingSession::Detection::Persistence do
  subject(:persistence) { described_class.new }

  let(:day) { Date.new(2026, 6, 10) }
  let!(:car) { Car.create!(id: 1) }
  let!(:other_car) { Car.create!(id: 2) }

  def at(hour, min = 0) = day.in_time_zone.change(hour:, min:)

  def detected(from, to, kwh: 10, car_id: nil, socs: {})
    ChargingSession::Detection::Session.new(started_at: from, ended_at: to, kwh:, kwh_grid: nil, cost: 3, cost_grid: nil, car_id:, socs:)
  end

  def stored(from, to, **)
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: from, ended_at: to, kwh: 5, **)
  end

  it 'updates the energy of an existing session and keeps its car and its note' do
    session = stored(at(8), at(9), car:, note: 'Trip')

    persistence.call(day => [detected(at(8), at(10), kwh: 12, car_id: 2)])

    expect(session.reload).to have_attributes(kwh: 12, ended_at: at(10), car_id: 1, note: 'Trip')
  end

  # The user removed the variables of the car instead of ending its period
  it 'keeps the car of a session also when the car has no configuration' do
    session = stored(at(8), at(9), car: Car.create!(id: 3))

    persistence.call(day => [detected(at(8), at(9), car_id: 1)])

    expect(Sensor::Cars.configured_numbers).not_to include(3)
    expect(session.reload.car_id).to eq(3)
  end

  it 'gives a session the state of charge of the car that it keeps' do
    stored(at(8), at(9), car: other_car, assigned_manually: true)

    persistence.call(day => [detected(at(8), at(9), car_id: 1, socs: { 1 => [30, 80], 2 => [40, 70] })])

    expect(ChargingSession.sole).to have_attributes(car_id: 2, soc_from: 40, soc_to: 70)
  end

  it 'gives a session without a car no state of charge' do
    persistence.call(day => [detected(at(8), at(9), socs: { 1 => [30, 80] })])

    expect(ChargingSession.sole).to have_attributes(soc_from: nil, soc_to: nil)
  end

  it 'keeps a guest mark' do
    session = stored(at(8), at(9), guest: true)

    persistence.call(day => [detected(at(8), at(9), car_id: 1)])

    expect(session.reload).to have_attributes(guest: true, car_id: nil)
  end

  it 'keeps "not assigned" that the user chose' do
    session = stored(at(8), at(9), assigned_manually: true)

    persistence.call(day => [detected(at(8), at(9), car_id: 2)])

    expect(session.reload).to have_attributes(car_id: nil, guest: false, assigned_manually: true)
  end

  it 'keeps the car that the user chose' do
    session = stored(at(8), at(9), car: other_car, assigned_manually: true)

    persistence.call(day => [detected(at(8), at(9), car_id: 1)])

    expect(session.reload).to have_attributes(car_id: 2, assigned_manually: true)
  end

  it 'gives the detection a session whose car of the user is outside its period' do
    session = stored(at(8), at(9), car: other_car, assigned_manually: true)
    other_car.update_columns(active_until: day - 1) # rubocop:disable Rails/SkipsModelValidations

    persistence.call(day => [detected(at(8), at(9), car_id: 1)])

    expect(session.reload).to have_attributes(car_id: 1, assigned_manually: false)
  end

  it 'keeps the choice of the user over a car of the detection when two removed sessions merge' do
    stored(at(8), at(9), car:)
    stored(at(9, 30), at(10, 30), car: other_car, assigned_manually: true)

    persistence.call(day => [detected(at(7, 55), at(10, 30), car_id: 1)])

    expect(ChargingSession.sole).to have_attributes(car_id: 2, assigned_manually: true)
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
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: at(8, 30), ended_at: at(8, 30), kwh: 5, guest: true)

    persistence.call(day => [detected(at(8), at(9), car_id: 1)])

    expect(ChargingSession.sole).to have_attributes(started_at: at(8), guest: true)
  end

  it 'removes the sessions of the day that the new result does not contain' do
    stored(at(18), at(19))

    persistence.call(day => [])

    expect(ChargingSession.count).to eq(0)
  end

  it 'never touches an offsite session' do
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(18), kwh: 5, cost: 2)

    persistence.call(day => [])

    expect(ChargingSession.offsite.count).to eq(1)
  end
end
