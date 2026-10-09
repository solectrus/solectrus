describe ChargingSession::Detection::StateOfCharge do
  subject(:state_of_charge) { described_class.new(cars, curves: ->(_date, name) { curves.fetch(name, []) }) }

  let(:car) { Car.new(id: 1, active_from: Date.new(2026, 1, 1)) }
  let(:other_car) { Car.new(id: 2, active_from: Date.new(2026, 1, 1)) }
  let(:cars) { [car, other_car] }
  let(:curves) { {} }

  def day = Date.new(2026, 6, 10)
  def at(hour, minute = 0) = day.in_time_zone.change(hour:, min: minute)

  it 'gives the last reading before the start and the highest reading up to 2 hours after the end' do
    curves[:car_battery_soc_1] = [[at(6), 40], [at(9), 55], [at(10), 70], [at(11, 30), 81], [at(13), 60]]

    expect(state_of_charge.call(day, at(8), at(10))).to eq(1 => [40, 81])
  end

  it 'reads each candidate' do
    curves[:car_battery_soc_1] = [[at(6), 40], [at(9), 60]]
    curves[:car_battery_soc_2] = [[at(6), 20], [at(9), 25]]

    expect(state_of_charge.call(day, at(8), at(10))).to eq(1 => [40, 60], 2 => [20, 25])
  end

  it 'gives nothing without a reading after the start' do
    curves[:car_battery_soc_1] = [[at(6), 40]]

    expect(state_of_charge.call(day, at(8), at(10))).to eq({})
  end

  it 'gives nothing when the state at the end is below the state at the start' do
    curves[:car_battery_soc_1] = [[at(6), 62], [at(8, 1), 40]]

    expect(state_of_charge.call(day, at(8), at(10))).to eq({})
  end

  it 'ignores a reading of 0' do
    curves[:car_battery_soc_1] = [[at(6), 40], [at(7), 0], [at(9), 60]]

    expect(state_of_charge.call(day, at(8), at(10))).to eq(1 => [40, 60])
  end

  it 'reads no car outside its period' do
    other_car.active_until = day - 1
    curves[:car_battery_soc_2] = [[at(6), 20], [at(9), 25]]

    expect(state_of_charge.call(day, at(8), at(10))).to eq({})
  end
end
