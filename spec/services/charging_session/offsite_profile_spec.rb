describe ChargingSession::OffsiteProfile do
  # The shares of the energy of the session: 30 kWh
  subject(:shares) { described_class.new([session]).call.map { |from, to, wh| [from, to, wh / 30_000] } }

  let(:car) { Car.create!(id: 1, active_from: Date.new(2026, 1, 1)) }
  let(:ended_at) { nil }
  let(:session) { ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(9), ended_at:, kwh: 30, cost: 10) }

  def at(hour, minute = 0) = Time.zone.local(2026, 6, 15, hour, minute)

  def write(sensor_name, readings)
    influx_batch do
      readings.each do |time, value|
        add_influx_point(name: Sensor::Config.measurement(sensor_name), fields: { Sensor::Config.field(sensor_name) => value }, time:)
      end
    end
  end

  # The first start and the last end of the shares, and their sum
  def extent = [shares.first.first, shares.last.second, shares.sum(&:last).round(6)]

  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_CONNECTED_1' => 'Trabant:connected',
        'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer',
      ),
    )
  end

  after { Sensor::Config.setup(ENV) }

  context 'without readings' do
    it 'spreads a session without an end over its whole day' do
      expect(extent).to eq([at(0), at(0) + 1.day, 1.0])
      expect(shares.map(&:last).uniq.size).to eq(1)
    end

    context 'with an end' do
      let(:ended_at) { at(9, 12) }

      it 'spreads the session from its start to its end' do
        expect(shares.map { it.first(2) }).to eq([[at(9), at(9, 5)], [at(9, 5), at(9, 10)], [at(9, 10), at(9, 12)]])
        expect(shares.map { it.last.round(4) }).to eq([0.4167, 0.4167, 0.1667])
      end
    end
  end

  context 'with a rise of the state of charge' do
    before do
      write(:car_battery_soc_1, [[at(8), 40], [at(11), 40], [at(12), 70], [at(14), 70]])
      # The car is plugged in all day, which the rise beats
      write(:car_connected_1, [[at(0), true]])
    end

    it 'follows the rise' do
      expect(extent).to eq([at(11), at(12), 1.0])
    end

    context 'with noise' do
      before { write(:car_battery_soc_1, [[at(20), 70], [at(20, 15), 71], [at(20, 30), 70]]) }

      it 'leaves it out' do
        expect(extent).to eq([at(11), at(12), 1.0])
      end
    end

    context 'with a slow charge in steps of 1 %' do
      before { write(:car_battery_soc_1, [[at(20), 70], [at(20, 15), 71], [at(20, 30), 71], [at(20, 45), 72]]) }

      it 'keeps it' do
        expect(shares.map(&:first)).to include(at(20, 40))
      end
    end
  end

  context 'with the plug and the odometer' do
    before do
      write(:car_connected_1, [[at(10), true], [at(13), false]])
      write(:car_odometer_1, [[at(12), 100], [at(12, 30), 100]])
    end

    it 'spreads the session over the time in which the car is plugged in' do
      expect(extent).to eq([at(10), at(13), 1.0])
    end

    context 'with a drive while plugged in' do
      before { write(:car_odometer_1, [[at(12, 30), 120]]) }

      it 'leaves out the drive' do
        expect(shares.map(&:first)).not_to include(at(12), at(12, 15))
        expect(extent).to eq([at(10), at(13), 1.0])
      end
    end
  end

  context 'with another session of the car' do
    before do
      ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: at(18), ended_at: at(20), kwh: 10, cost: 3)
    end

    it 'leaves out its time' do
      expect(shares.map(&:first)).not_to include(at(18), at(19, 55))
      expect(shares.map(&:first)).to include(at(17, 55), at(20))
    end

    # The readings come every 15 minutes, so the rise of the wallbox session
    # starts before it
    context 'with a rise that reaches into it' do
      before { write(:car_battery_soc_1, [[at(11), 40], [at(12), 60], [at(17, 50), 60], [at(18, 5), 65], [at(20), 80]]) }

      it 'leaves out the whole rise' do
        expect(extent).to eq([at(11), at(12), 1.0])
      end
    end
  end
end
