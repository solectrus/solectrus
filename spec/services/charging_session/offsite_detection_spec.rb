describe ChargingSession::OffsiteDetection do
  subject(:detection) { described_class.new(dates) }

  let(:dates) { [day] }
  let!(:car) { Car.create!(id: 1, active_from: Date.new(2026, 1, 1), battery_kwh: 50) }

  def day = Date.new(2026, 6, 15)
  def at(hour, minute = 0, date: day) = date.in_time_zone.change(hour:, min: minute)

  def write(sensor_name, readings)
    influx_batch do
      readings.each do |time, value|
        add_influx_point(name: Sensor::Config.measurement(sensor_name), fields: { Sensor::Config.field(sensor_name) => value }, time:)
      end
    end
  end

  def run = detection.persist(detection.call)

  def proposals
    ChargingSession.proposals.order(:started_at).map { [it.started_at, it.ended_at, it.soc_from.to_f, it.soc_to.to_f, it.kwh&.to_f] }
  end

  # A position in one point, like a collector sends it
  def write_position(time, latitude, longitude)
    influx_batch do
      add_influx_point(name: 'Trabant', fields: { 'latitude' => latitude, 'longitude' => longitude }, time:)
    end
  end

  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_CONNECTED_1' => 'Trabant:connected',
        'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer',
        'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
        'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
      ),
    )
  end

  after { Sensor::Config.setup(ENV) }

  it 'is enabled with the state of charge of a car' do
    expect(described_class).to be_enabled
  end

  context 'with a rise of the state of charge' do
    before { write(:car_battery_soc_1, [[at(8), 30], [at(10), 30], [at(10, 30), 50], [at(11), 70], [at(13), 70]]) }

    it 'proposes an offsite session with the estimate of the energy' do
      run

      expect(proposals).to eq([[at(10), at(11), 30.0, 70.0, 20.0]])
      expect(ChargingSession.proposals.first).to have_attributes(car_id: 1, cost: nil, assigned_manually: false, origin: 'detection')
    end

    it 'gives no energy without the capacity of the car' do
      car.update!(battery_kwh: nil)

      run

      expect(proposals.first.last).to be_nil
    end

    it 'replaces the proposals of its days, but keeps an accepted session' do
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(18), kwh: 5, cost: 2)
      run

      expect { run }.not_to change(ChargingSession, :count)
    end

    it 'makes no proposal beside an entered session' do
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(11, 30), ended_at: at(12), kwh: 20, cost: 9)

      run

      expect(proposals).to be_empty
    end

    it 'gives an entered session the state of charge of its rise' do
      session = ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(10, 5), ended_at: at(11), kwh: 20, cost: 9)

      run

      expect(session.reload).to have_attributes(soc_from: 30, soc_to: 70)
    end

    it 'gives two entered sessions with one rise no state of charge' do
      sessions = [at(10), at(10, 30)].map { ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: it, ended_at: it + 20.minutes, kwh: 10, cost: 5) }

      run

      expect(sessions.map { it.reload.soc_from }).to eq([nil, nil])
    end

    it 'gives a dismissed proposal no state of charge' do
      run
      ChargingSession.proposals.first.tap { it.update_columns(soc_from: nil, soc_to: nil) }.dismiss! # rubocop:disable Rails/SkipsModelValidations

      run

      expect(ChargingSession.sole).to have_attributes(dismissed: true, soc_from: nil)
    end

    it 'makes no proposal on the day of an entered session without an end' do
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(20), kwh: 20, cost: 9)

      run

      expect(proposals).to be_empty
    end

    it 'makes no proposal again after a dismissal' do
      run
      ChargingSession.proposals.first.dismiss!

      run

      expect(proposals).to be_empty
    end

    it 'makes no proposal during a wallbox session of the car' do
      ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: at(9), ended_at: at(12), kwh: 10)

      run

      expect(proposals).to be_empty
    end

    it 'makes no proposal after a wallbox session, because the car reports late' do
      ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: at(8), ended_at: at(9, 30), kwh: 10)

      run

      expect(proposals).to be_empty
    end

    it 'ignores the wallbox session of a guest' do
      ChargingSession.create!(kind: :wallbox, origin: :detection, guest: true, assigned_manually: true, started_at: at(9), ended_at: at(12), kwh: 10)

      run

      expect(proposals.size).to eq(1)
    end

    it 'makes no proposal while the car reports no connection' do
      write(:car_connected_1, [[at(7), false]])

      run

      expect(proposals).to be_empty
    end

    # The position of the morning ends with the drive, so the car is not at
    # home anymore
    it 'ends a position when the car drives away' do
      Place.create!(latitude: 50.9226, longitude: 6.4070, labels: ['home'])
      write_position(at(6), 50.9226, 6.4070)
      write(:car_odometer_1, [[at(6), 1000], [at(9), 1050]])

      run

      expect(ChargingSession.proposals.first).to have_attributes(latitude: nil)
    end

    context 'with a home' do
      before { Place.create!(latitude: 50.9226, longitude: 6.4070, labels: ['home']) }

      context 'when the car is at home' do
        before { write_position(at(7), 50.9226, 6.4070) }

        it 'makes no proposal' do
          run

          expect(proposals).to be_empty
        end
      end

      context 'when the car is away' do
        before { write_position(at(7), 50.0, 8.0) }

        it 'keeps the position' do
          run

          expect(ChargingSession.proposals.first).to have_attributes(latitude: 50.0, longitude: 8.0)
        end

        it 'gives an entered session the position of its rise' do
          session = ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(10, 5), ended_at: at(11), kwh: 20, cost: 9)

          run

          expect(session.reload).to have_attributes(latitude: 50.0, longitude: 8.0)
        end

        it 'proposes a session also after a wallbox session' do
          ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: at(8), ended_at: at(9, 30), kwh: 10)

          run

          expect(proposals.size).to eq(1)
        end
      end
    end
  end

  # A trip with two stops at chargers, and an earlier charge that the user
  # entered without an end
  context 'with two stops on a trip' do
    # The first stop, the second stop and the session of the day
    let!(:sessions) do
      [[at(10), at(10, 30)], [at(10, 45), at(11, 15)], [at(18), nil]].map do |started_at, ended_at|
        ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at:, ended_at:, kwh: 5, cost: 2)
      end
    end

    before do
      write(:car_battery_soc_1, [[at(6), 20], [at(7), 20], [at(8), 35], [at(9, 30), 30], [at(10), 30], [at(10, 30), 40], [at(10, 45), 41], [at(11, 15), 60], [at(13), 60]])
      write(:car_odometer_1, [[at(6), 1000], [at(10, 30), 1000], [at(10, 45), 1020]])
    end

    it 'gives each stop its rise, cut by the drive, and the day session the rise that is left' do
      run

      expect(sessions.map { [it.reload.soc_from, it.soc_to] }).to eq([[30, 40], [41, 60], [20, 35]])
    end
  end

  it 'gives an entered session without an end no state of charge on a day with two rises' do
    write(:car_battery_soc_1, [[at(8), 30], [at(9), 30], [at(10), 50], [at(12), 40], [at(13), 40], [at(14), 60], [at(16), 60]])
    session = ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(12), kwh: 20, cost: 9)

    run

    expect(session.reload.soc_from).to be_nil
  end

  it 'takes a small rise while the car reports a connection' do
    write(:car_battery_soc_1, [[at(8), 30], [at(10), 30], [at(11), 34], [at(13), 34]])
    write(:car_connected_1, [[at(9, 55), true], [at(11, 5), false]])

    run

    expect(proposals).to eq([[at(10), at(11), 30.0, 34.0, 2.0]])
  end

  it 'ignores a rise below 3 points also with a connection' do
    write(:car_battery_soc_1, [[at(8), 30], [at(10), 30], [at(11), 32], [at(13), 32]])
    write(:car_connected_1, [[at(9, 55), true]])

    run

    expect(proposals).to be_empty
  end

  it 'ignores a small rise' do
    write(:car_battery_soc_1, [[at(8), 30], [at(10), 30], [at(11), 34], [at(13), 34]])

    run

    expect(proposals).to be_empty
  end

  it 'ignores a reading of 0' do
    write(:car_battery_soc_1, [[at(8), 30], [at(10), 0], [at(11), 32], [at(13), 32]])

    run

    expect(proposals).to be_empty
  end

  # The odometer reports the end of the drive late, in the first reading of
  # the charge
  it 'leaves out a step of a drive, but keeps the rest of the rise' do
    write(:car_battery_soc_1, [[at(8), 50], [at(10), 46], [at(10, 30), 52], [at(11), 80], [at(13), 80]])
    write(:car_odometer_1, [[at(8), 1000], [at(10, 30), 1150]])

    run

    expect(proposals).to eq([[at(10, 30), at(11), 52.0, 80.0, 14.0]])
  end

  context 'with a rise over midnight' do
    let(:dates) { [day, day + 1] }

    before { write(:car_battery_soc_1, [[at(22), 30], [at(23), 30], [at(1, date: day + 1), 80], [at(3, date: day + 1), 80]]) }

    it 'gives the rise to the day of its start' do
      run

      expect(proposals).to eq([[at(23), at(1, date: day + 1), 30.0, 80.0, 25.0]])
    end

    it 'gives the next day no second proposal' do
      described_class.new([day]).then { it.persist(it.call) }
      described_class.new([day + 1]).then { it.persist(it.call) }

      expect(proposals.size).to eq(1)
    end
  end
end
