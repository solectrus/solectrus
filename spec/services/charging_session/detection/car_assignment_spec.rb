describe ChargingSession::Detection::CarAssignment do
  subject(:assignment) { described_class.new(cars, curves: ->(_date, name) { curves.fetch(name, []) }) }

  let(:car) { Car.new(id: 1) }
  let(:other_car) { Car.new(id: 2) }
  let(:cars) { [car, other_car] }
  let(:curves) { {} }

  def day = Date.new(2026, 6, 10)
  def at(hour) = day.in_time_zone.change(hour:)
  def from = at(8)
  def to = at(10)

  it 'takes the one candidate' do
    other_car.active_until = day - 1

    expect(assignment.car_for(day, from, to)).to eq(car)
  end

  it 'takes the car whose state of charge rises during the session' do
    curves[:car_battery_soc_1] = [[at(7), 60], [at(11), 60]]
    curves[:car_battery_soc_2] = [[at(7), 30], [at(11), 70]]

    expect(assignment.car_for(day, from, to)).to eq(other_car)
  end

  it 'excludes a car that drives during the session' do
    curves[:car_mileage_1] = [[at(8), 1000], [at(9), 1040]]

    expect(assignment.car_for(day, from, to)).to eq(other_car)
  end

  it 'leaves the session open without a sign' do
    expect(assignment.car_for(day, from, to)).to be_nil
  end

  it 'ignores a reading far from the session' do
    curves[:car_battery_soc_2] = [[at(1), 30], [at(20), 70]]

    expect(assignment.car_for(day, from, to)).to be_nil
  end

  it 'reads the curves of the cars only on a day with more than one candidate' do
    allow(Sensor::Config).to receive(:configured?).and_return(true)

    expect(assignment.sensor_names([day])).to eq(%i[car_battery_soc_1 car_mileage_1 car_battery_soc_2 car_mileage_2])

    other_car.active_until = day - 1
    expect(assignment.sensor_names([day])).to be_empty
  end
end
