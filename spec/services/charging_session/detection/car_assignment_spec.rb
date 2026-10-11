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
    curves[:car_odometer_1] = [[at(8), 1000], [at(9), 1040]]

    expect(assignment.car_for(day, from, to)).to eq(other_car)
  end

  it 'leaves the session open without a sign' do
    expect(assignment.car_for(day, from, to)).to be_nil
  end

  it 'ignores a reading far from the session' do
    curves[:car_battery_soc_2] = [[at(1), 30], [at(20), 70]]

    expect(assignment.car_for(day, from, to)).to be_nil
  end

  describe 'with the connection of a car' do
    it 'takes the one car that reports a connection' do
      curves[:car_connected_1] = [[at(9), 0]]
      curves[:car_connected_2] = [[at(9), 1]]

      expect(assignment.car_for(day, from, to)).to eq(other_car)
    end

    it 'prefers the connection over the state of charge' do
      curves[:car_connected_1] = [[at(9), 1]]
      curves[:car_battery_soc_2] = [[at(7), 30], [at(11), 70]]

      expect(assignment.car_for(day, from, to)).to eq(car)
    end

    it 'takes the last reading before the session without one during it' do
      curves[:car_connected_2] = [[at(7), 1]]

      expect(assignment.car_for(day, from, to)).to eq(other_car)
    end

    # The car reports no connection on the drive home and nothing after it
    # is plugged in, for example without reception in the garage
    it 'ignores a missing connection before the session' do
      other_car.active_until = day - 1
      curves[:car_connected_1] = [[at(7), 0]]

      expect(assignment.car_for(day, from, to)).to eq(car)
    end

    it 'excludes a car that reports no connection' do
      curves[:car_connected_1] = [[at(9), 0]]

      expect(assignment.car_for(day, from, to)).to eq(other_car)
    end

    it 'leaves the session open when the one candidate reports no connection' do
      other_car.active_until = day - 1
      curves[:car_connected_1] = [[at(9), 0]]

      expect(assignment.car_for(day, from, to)).to be_nil
    end

    # A car that is offline while it charges repeats its last state
    it 'keeps a car without a connection whose state of charge rises' do
      other_car.active_until = day - 1
      curves[:car_connected_1] = [[at(9), 0]]
      curves[:car_battery_soc_1] = [[at(7), 30], [at(10), 70]]

      expect(assignment.car_for(day, from, to)).to eq(car)
    end

    # The source repeats the last state of a car that is offline
    it 'ignores a missing connection that an offline car repeats' do
      other_car.active_until = day - 1
      curves[:car_connected_1] = [[at(7), 0], [at(9), 0]]
      curves[:car_battery_soc_1] = [[at(7), 40], [at(9), 40]]

      expect(assignment.car_for(day, from, to)).to eq(car)
    end

    it 'excludes a car without a connection whose other readings change' do
      other_car.active_until = day - 1
      curves[:car_connected_1] = [[at(7), 0], [at(9), 0]]
      curves[:car_battery_soc_1] = [[at(7), 40], [at(9), 35]]

      expect(assignment.car_for(day, from, to)).to be_nil
    end

    # A car reports late, so a short session at its arrival has the
    # connection after it
    it 'takes a connection that the car reports shortly after the session' do
      curves[:car_connected_1] = [[at(9), 0], [to + 10.minutes, 1]]

      expect(assignment.car_for(day, from, to)).to eq(car)
    end

    it 'ignores a connection that the car reports long after the session' do
      curves[:car_connected_1] = [[at(9), 0], [to + 30.minutes, 1]]

      expect(assignment.car_for(day, from, to)).to eq(other_car)
    end

    it 'lets the heuristics choose between two connected cars' do
      curves[:car_connected_1] = [[at(9), 1]]
      curves[:car_connected_2] = [[at(9), 1]]
      curves[:car_battery_soc_1] = [[at(7), 30], [at(11), 70]]

      expect(assignment.car_for(day, from, to)).to eq(car)
    end

    it 'ignores a reading far from the session' do
      other_car.active_until = day - 1
      curves[:car_connected_1] = [[at(5), 0]]

      expect(assignment.car_for(day, from, to)).to eq(car)
    end
  end

  describe 'with home' do
    subject(:assignment) { described_class.new(cars, curves: ->(_date, name) { curves.fetch(name, []) }, home:) }

    let(:home) { Place.new(latitude: 50.92263, longitude: 6.40706) }

    def position(name, time, latitude, longitude)
      curves[:"car_latitude_#{name}"] = [*curves[:"car_latitude_#{name}"], [time, latitude]]
      curves[:"car_longitude_#{name}"] = [*curves[:"car_longitude_#{name}"], [time, longitude]]
    end

    it 'excludes a car away from home during the session' do
      position(1, at(9), 50.906, 6.407)

      expect(assignment.car_for(day, from, to)).to eq(other_car)
    end

    it 'excludes a car away from home also with a connection' do
      position(1, at(9), 50.906, 6.407)
      curves[:car_connected_1] = [[at(9), 1]]

      expect(assignment.car_for(day, from, to)).to eq(other_car)
    end

    it 'leaves the session open when the one car is away' do
      other_car.active_until = day - 1
      position(1, at(9), 50.906, 6.407)

      expect(assignment.car_for(day, from, to)).to be_nil
    end

    it 'gives no sign for a car at home' do
      position(1, at(9), 50.92270, 6.40710)

      expect(assignment.car_for(day, from, to)).to be_nil
    end

    it 'takes a car that reports home shortly after the session' do
      other_car.active_until = day - 1
      position(1, at(9), 50.906, 6.407)
      position(1, to + 10.minutes, 50.92270, 6.40710)

      expect(assignment.car_for(day, from, to)).to eq(car)
    end

    it 'ignores the position before the session, from the drive home' do
      position(1, at(8), 50.906, 6.407)

      expect(assignment.car_for(day, from, to)).to be_nil
    end
  end
end
