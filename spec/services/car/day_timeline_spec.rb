describe Car::DayTimeline do
  subject(:timeline) { described_class.new(Timeframe.new('2025-12-28'), [car]) }

  let(:car) { Car.create!(id: 1) }

  def at(hour, minute = 0) = Time.zone.local(2025, 12, 28, hour, minute)

  # The times of the charge of the session in the lane of the car
  def spans(session) = timeline.lanes.sole.charges.find { it.session == session }.spans

  it 'starts the curves of the wallbox only for a wallbox session' do
    curves = instance_double(ChargingSession::Curves, start: nil)
    allow(ChargingSession::Curves).to receive(:new).and_return(curves)
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(16, 55), ended_at: at(17, 35), kwh: 7, cost: 3)

    timeline.start

    expect(curves).to have_received(:start).with(wallbox: false)
  end

  it 'takes the times of a session with an end' do
    session = ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(16, 55), ended_at: at(17, 35), kwh: 7, cost: 3)

    expect(spans(session)).to eq([[at(16, 55), at(17, 35)]])
  end

  # The session belongs to the day of its start, but it charged on both days
  context 'with an offsite session over midnight' do
    let!(:session) { ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(22), ended_at: at(3) + 1.day, kwh: 30, cost: 9) }

    it 'charges up to midnight on the day of its start' do
      expect(spans(session)).to eq([[at(22), at(0) + 1.day]])
    end

    it 'charges from midnight on the next day' do
      timeline = described_class.new(Timeframe.new('2025-12-29'), [car])

      expect(timeline.lanes.sole.charges.sole.spans).to eq([[at(0) + 1.day, at(3) + 1.day]])
    end

    # Like the part of a wallbox session that the detection split at midnight
    it 'leaves out a session that ends at midnight on the next day' do
      session.update!(ended_at: at(0) + 1.day)
      timeline = described_class.new(Timeframe.new('2025-12-29'), [car])

      expect(timeline.lanes.sole.charges).to be_empty
    end

    it 'leaves it out on a later day' do
      timeline = described_class.new(Timeframe.new('2025-12-30'), [car])

      expect(timeline.lanes.sole.charges).to be_empty
    end
  end

  context 'with an offsite session without an end' do
    let!(:session) { ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(10, 35), kwh: 36, cost: 12) }

    it 'charges where the signs of its car tell it, from its start to the end of its day' do
      allow(Car::DayTimeline::OffsiteEstimate).to receive(:new).and_return(instance_double(Car::DayTimeline::OffsiteEstimate, call: [at(10, 35), at(10, 45)]))

      expect(spans(session)).to eq([[at(10, 35), at(10, 45)]])
      expect(Car::DayTimeline::OffsiteEstimate).to have_received(:new).with(hash_including(from: at(10, 35), to: at(0) + 1.day))
    end

    it 'charges before the next session of the car' do
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(16, 10), kwh: 10, cost: 4)

      expect(spans(session)).to eq([[at(10, 35), at(16, 10)]])
    end

    it 'charges over the rest of the day without a time' do
      allow(Car::DayTimeline::OffsiteEstimate).to receive(:new).and_return(instance_double(Car::DayTimeline::OffsiteEstimate, call: nil))

      expect(spans(session)).to eq([[at(10, 35), at(0) + 1.day]])
    end
  end

  # The state of charge rose in the session with an end, so the session
  # without an end charged while the car was plugged in
  context 'with an offsite session with an end and one without' do
    let!(:session) { ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(15), kwh: 10, cost: 4) }

    before do
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(12), ended_at: at(13), kwh: 20, cost: 8)
      Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_CONNECTED_1' => 'Trabant:connected'))

      influx_batch do
        [[at(11, 50), 40], [at(13), 70], [at(23), 70]].each do |time, value|
          add_influx_point(name: Sensor::Config.measurement(:car_battery_soc_1), fields: { Sensor::Config.field(:car_battery_soc_1) => value }, time:)
        end
        [[at(18), true], [at(20), false]].each do |time, value|
          add_influx_point(name: 'Trabant', fields: { 'connected' => value }, time:)
        end
      end
    end

    after { Sensor::Config.setup(ENV) }

    # A reading carries the end of its bucket, like the time plugged in
    it 'leaves out the time of the other session' do
      expect(spans(session)).to eq([[at(18, 5), at(20, 5)]])
    end
  end

  # The session paused until the night while the car stayed plugged in, so
  # it charged in two parts
  context 'with a wallbox session with a pause' do
    let!(:session) { ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: at(14, 40), ended_at: at(23, 20), kwh: 7) }

    # The wallbox had power in the afternoon and at night, and its collector
    # sent no data before the power of the night
    let(:gap_buckets) { [at(22, 55), at(23, 0), at(23, 5), at(23, 10)] }

    before do
      power = [*(45..70).step(5).map { at(14) + it.minutes }, at(23, 15), at(23, 20)].map { [it, 5000.0] }
      connected = (0..105).map { [at(14, 40) + (it * 5).minutes, 1.0] }
      gaps = gap_buckets.map { [it, 0.0] }
      day = Date.new(2025, 12, 28)
      curves = instance_double(ChargingSession::Curves, start: nil, cars: {}, wallbox: { day => { wallbox_power: power, wallbox_car_connected: connected } }, wallbox_gaps: { day => { wallbox_power: gaps } })
      allow(ChargingSession::Curves).to receive(:new).and_return(curves)
    end

    # Like the detection, the part reaches back over the buckets without data
    # to the start of the bucket with data before them
    it 'charges where the wallbox had power or sent no data' do
      expect(spans(session)).to eq([[at(14, 40), at(15, 10)], [at(22, 45), at(23, 20)]])
    end

    # Each bucket without data covers the 5 minutes before its end. The
    # bucket before them holds the last readings, without power.
    it 'keeps the time without data as a gap, from the bucket before it' do
      expect(timeline.lanes.sole.charges.sole.gaps).to eq([[at(22, 45), at(23, 10)]])
    end

    # The power of the afternoon stays in view
    context 'with a gap after a bucket with power' do
      let(:gap_buckets) { [at(15, 15), at(15, 20), at(22, 55), at(23, 0), at(23, 5), at(23, 10)] }

      it 'starts the gap after it' do
        expect(timeline.lanes.sole.charges.sole.gaps.first).to eq([at(15, 10), at(15, 20)])
      end
    end

    it 'keeps the whole session as the time in which the car stood' do
      expect(timeline.lanes.sole.charges.sole.span).to eq([at(14, 40), at(23, 20)])
    end

    # The session has no split of the power splitter, so the curves need no
    # grid share
    it 'draws the power of the wallbox over the session, unsplit' do
      power = timeline.lanes.sole.charges.sole.power

      expect(power.values_at(0, 1, -1).map(&:time)).to eq([at(14, 40), at(14, 42) + 30.seconds, at(23, 20)])
      expect(power.map(&:unsplit).uniq).to eq([5000.0, 0.0])
      expect(ChargingSession::Curves).to have_received(:new).with(anything, hash_including(split: false))
    end

    # The build stored the session before the power of the night came
    context 'with an end before the last part' do
      let!(:session) { ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: at(14, 40), ended_at: at(15, 10), kwh: 2) }

      it 'charges up to the end' do
        expect(spans(session)).to eq([[at(14, 40), at(15, 10)]])
      end
    end
  end

  # The bucket of a reading carries the end of its 5 minutes, which on the
  # running day lies after now
  context 'with a reading in the running bucket' do
    subject(:timeline) { described_class.new(Timeframe.new('day'), [car]) }

    before do
      travel_to at(10, 2)
      Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_BATTERY_SOC_1' => 'Trabant:soc'))
      soc = [[at(9, 50), 60.0], [at(10, 5), 70.0]]
      curves = instance_double(ChargingSession::Curves, start: nil, cars: { at(0).to_date => { car_battery_soc_1: soc } }, wallbox: {}, wallbox_gaps: {})
      allow(ChargingSession::Curves).to receive(:new).and_return(curves)
    end

    after { Sensor::Config.setup(ENV) }

    it 'shows it at now' do
      expect(timeline.lanes.sole.soc_at(at(10, 2))).to eq(70.0)
    end
  end

  # The visits follow each other without a gap, because the car reports its
  # place after the drive: the visit of the school lasts until the car
  # arrives at work
  describe Car::DayTimeline::Lane do
    def visit(name, from, to) = PlaceVisit.new(started_at: from, ended_at: to, place: Place.new(name:))

    let(:lane) do
      visits = [visit('Home', at(0), at(7, 41)), visit('School', at(7, 41), at(8, 26)), visit('Work', at(8, 26), at(23))]
      described_class.new(car: nil, drives: [], charges: [], soc_line: [], visits:)
    end

    it 'starts a drive at the last place where the car arrived before it' do
      drive = Car::DayTimeline::Drives::Drive.new(started_at: at(7, 45), ended_at: at(8, 15), distance: 11)

      expect([lane.origin(drive), lane.goal(drive)].map(&:name)).to eq(%w[School Work])
    end

    # The stop between was too short for a visit, so the visit at work goes on
    it 'ends a round trip at the place where it started' do
      drive = Car::DayTimeline::Drives::Drive.new(started_at: at(12), ended_at: at(13), distance: 33)

      expect([lane.origin(drive), lane.goal(drive)].map(&:name)).to eq(%w[Work Work])
    end

    # The car reports its arrival late, so the visit of the school lasts
    # some minutes past the end of a drive to a place without a visit
    it 'takes no goal from a visit that ends after the drive within the late report' do
      drive = Car::DayTimeline::Drives::Drive.new(started_at: at(7, 45), ended_at: at(8, 10), distance: 11)
      lane = described_class.new(car: nil, drives: [], charges: [], soc_line: [], visits: [visit('School', at(7, 41), at(8, 26))])

      expect([lane.origin(drive)&.name, lane.goal(drive)]).to eq(['School', nil])
    end

    # The drive ends at the arrival (see Car::DayTimeline::Drives#cut)
    it 'ends a drive without a start at the place where it arrived' do
      drive = Car::DayTimeline::Drives::Drive.new(started_at: nil, ended_at: at(8, 26), distance: 11)

      expect([lane.origin(drive), lane.goal(drive)].map(&:name)).to eq(%w[School Work])
    end

    # The car stands at the shop for less than Place::MIN_DURATION, so the
    # build wrote no visit there yet
    context 'with the place where the car stands now' do
      let(:drives) do
        [
          Car::DayTimeline::Drives::Drive.new(started_at: at(7, 45), ended_at: at(8, 15), distance: 11),
          Car::DayTimeline::Drives::Drive.new(started_at: at(17, 5), ended_at: at(17, 15), distance: 8),
        ]
      end
      let(:lane) do
        visits = [visit('School', at(7, 41), at(8, 15)), visit('Work', at(8, 15), at(17, 12))]
        described_class.new(car: nil, drives:, charges: [], soc_line: [], visits:, current_place: Place.new(name: 'Shop'))
      end

      it 'ends the last drive there' do
        expect([lane.origin(drives.last), lane.goal(drives.last)].map(&:name)).to eq(%w[Work Shop])
      end

      it 'keeps the goal of an earlier drive' do
        expect(lane.goal(drives.first).name).to eq('Work')
      end
    end
  end

  describe '.without' do
    it 'cuts the times out of the spans' do
      expect(described_class.without([[at(8), at(12)]], [[at(9), at(10)], [at(11), at(13)]])).to eq([[at(8), at(9)], [at(10), at(11)]])
    end

    # Like a drive without a start
    it 'keeps a span whole at a cut without a length' do
      expect(described_class.without([[at(8), at(12)]], [[at(10), at(10)]])).to eq([[at(8), at(12)]])
    end
  end
end
