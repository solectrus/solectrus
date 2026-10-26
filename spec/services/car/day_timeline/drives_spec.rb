describe Car::DayTimeline::Drives do
  subject(:drives) { described_class.new(readings, before:, soc:, stops:).call }

  let(:before) { nil }
  let(:soc) { [] }
  let(:stops) { [] }

  def at(hour, minute = 0) = Time.zone.local(2026, 6, 15, hour, minute)

  # [started_at, ended_at, distance] of each drive, the times as "HH:MM"
  def spans = drives.map { [it.started_at&.strftime('%H:%M'), it.ended_at.strftime('%H:%M'), it.distance] }

  context 'with a car that writes its odometer while it drives' do
    let(:readings) { [[at(9), 100], [at(9, 15), 104], [at(9, 30), 109], [at(12), 109], [at(12, 20), 112]] }

    it 'joins the increases one after the other into one drive' do
      expect(spans).to eq([['09:00', '09:30', 9], ['12:00', '12:20', 3]])
    end
  end

  # The odometer tells only that the car drove since the reading before
  context 'with a long gap before an increase' do
    let(:readings) { [[at(6), 100], [at(12, 30), 103]] }

    it 'knows the end of the drive, but not its start' do
      expect(spans).to eq([[nil, '12:30', 3]])
    end
  end

  # A car that reports each hour missed a reading during a long drive
  context 'with a gap of a missed reading before an increase' do
    let(:readings) { [[at(13, 20), 100], [at(15, 20), 310], [at(16, 20), 355]] }
    let(:soc) { [[at(13, 20), 75], [at(15, 20), 20], [at(16, 20), 13]] }

    it 'starts the drive at the earliest at the reading before the gap, as an estimate' do
      drive = drives.sole

      expect([drive.started_at, drive.earliest_at, drive.ended_at, drive.distance]).to eq([nil, at(13, 20), at(16, 20), 255])
      expect(drive).to be_estimated_start
    end
  end

  context 'with the first reading of the day above the reading before it' do
    let(:before) { [at(0) - 2.hours, 100] }
    let(:readings) { [[at(8), 104]] }

    it 'counts the increase, without a start' do
      expect(spans).to eq([[nil, '08:00', 4]])
    end
  end

  context 'without a reading before the day' do
    let(:readings) { [[at(8), 104], [at(8, 15), 106]] }

    it 'starts at the first reading of the day' do
      expect(spans).to eq([['08:00', '08:15', 2]])
    end
  end

  # Some collectors send 0 while the car is offline, and the source rounds
  context 'with a wrong reading and a small step back' do
    let(:readings) { [[at(8), 100], [at(8, 15), 0], [at(8, 30), 99.6], [at(8, 45), 100], [at(9), 103]] }

    it 'adds no drive for either' do
      expect(spans).to eq([['08:45', '09:00', 3]])
    end
  end

  # The odometer of some cars stands still while they drive, but the state of
  # charge falls
  context 'with an odometer that catches up after the drive' do
    let(:readings) { [[at(9), 100], [at(9, 15), 100], [at(11), 100], [at(11, 15), 180]] }
    let(:soc) { [[at(9), 90], [at(9, 15), 90], [at(9, 30), 85], [at(10), 75], [at(10, 30), 65], [at(11), 60], [at(11, 15), 60]] }

    it 'takes the drive from the fall of the state of charge' do
      expect(spans).to eq([['09:15', '11:00', 80]])
    end
  end

  context 'with a short pause between two drives' do
    let(:readings) { [[at(9), 100], [at(9, 30), 110], [at(9, 45), 110], [at(10), 110], [at(10, 15), 120]] }

    it 'joins them' do
      expect(spans).to eq([['09:00', '10:15', 20]])
    end

    # The car stood at a place or charged, so the pause is a stop
    context 'with a stop in the pause' do
      let(:stops) { [[at(9, 35), at(9, 55)]] }

      it 'keeps them apart' do
        expect(spans).to eq([['09:00', '09:30', 10], ['10:00', '10:15', 10]])
      end
    end
  end

  # The car plugged in before it reported the odometer
  context 'with a charge that starts before the reading of the drive' do
    let(:readings) { [[at(9), 100], [at(9, 30), 110]] }
    let(:stops) { [[at(9, 25), at(11)]] }

    it 'ends the drive at the charge' do
      expect(spans).to eq([['09:00', '09:25', 10]])
    end
  end

  # The car drove to a shop and back. The state of charge fell by a point
  # while it stood there, which is no drive.
  context 'with a fall of the state of charge in a visit' do
    let(:readings) { [[at(9), 100], [at(9, 10), 104], [at(10, 20), 108]] }
    let(:soc) { [[at(9), 43], [at(9, 10), 42], [at(10, 10), 41], [at(10, 20), 39]] }
    let(:stops) { [[at(0), at(9, 5)], [at(9, 5), at(10, 18)], [at(10, 18), at(23)]] }

    it 'keeps the drive there and the drive back apart' do
      expect(spans).to eq([['09:00', '09:05', 4], ['10:10', '10:18', 4]])
    end
  end

  # A car that reports its place late: the visit at home lasts until the
  # car arrives at the next place. The state of charge falls by 6 points in
  # each quarter of an hour, which is a drive also within the visit.
  context 'with a long drive within the end of a visit' do
    let(:readings) { [[at(9, 45), 100], [at(10), 100], [at(10, 15), 169]] }
    let(:soc) { [[at(9), 99], [at(9, 15), 99], [at(9, 30), 93], [at(9, 45), 87], [at(10), 82], [at(10, 15), 82]] }
    let(:stops) { [[at(0), at(10, 13)], [at(10, 13), at(15, 43)]] }

    it 'takes the drive from the fall of the state of charge' do
      expect(spans).to eq([['09:15', '10:00', 69]])
    end
  end

  # A car on the way to school and on to work. Both drives touch, but the car
  # arrived at the school between them.
  context 'with an arrival between two drives that touch' do
    let(:readings) { [[at(7), 100], [at(7, 15), 100], [at(7, 30), 107], [at(7, 45), 117], [at(8), 117], [at(8, 15), 117], [at(8, 30), 128]] }
    let(:soc) { [[at(7), 58], [at(7, 15), 55], [at(7, 30), 52], [at(7, 45), 50], [at(8), 49], [at(8, 15), 47], [at(8, 30), 47]] }
    let(:stops) { [[at(0), at(7, 41)], [at(7, 41), at(8, 26)], [at(8, 26), at(23)]] }

    it 'keeps them apart, each up to its arrival' do
      expect(spans).to eq([['07:00', '07:41', 17], ['07:45', '08:15', 11]])
    end
  end

  # The state of charge read last before the arrival, so the fall of the next
  # drive reaches back over it
  context 'with a fall of the next drive from a reading before the arrival' do
    let(:readings) { [[at(9, 30), 100], [at(10, 5), 110], [at(10, 30), 110], [at(10, 45), 115]] }
    let(:soc) { [[at(9, 30), 80], [at(9, 50), 78], [at(10, 40), 76], [at(10, 45), 76]] }
    let(:stops) { [[at(10), at(10, 35)], [at(10, 50), at(23)]] }

    it 'starts the next drive at the arrival and keeps both apart' do
      expect(spans).to eq([['09:30', '09:50', 10], ['10:00', '10:40', 5]])
    end
  end

  # The car arrived at a fast charger at 13:47 and reported the odometer in
  # the bucket up to 14:05, less than REPORT_LAG after it plugged in
  context 'with an odometer that reports at the charge after the drive' do
    let(:readings) { [[at(10, 35), 100], [at(13, 50), 100], [at(14, 5), 342]] }
    let(:soc) { [[at(10, 35), 92], [at(11, 35), 76], [at(12, 35), 46], [at(13, 35), 16], [at(13, 50), 12], [at(14, 5), 22]] }

    it 'ends the drive at the charge' do
      drives = described_class.new(readings, soc:, charges: [[at(13, 47), at(15, 41)]]).call

      expect(drives.map { [it.started_at&.strftime('%H:%M'), it.ended_at.strftime('%H:%M'), it.distance] }).to eq([['10:35', '13:47', 242]])
    end
  end

  # The car plugged in on the way, before the odometer read the drive
  context 'with a recorded charge in the drive' do
    let(:readings) { [[at(9), 100], [at(9, 50), 110]] }

    it 'ends the drive where the charge starts' do
      drives = described_class.new(readings, charges: [[at(9, 30), at(10)]]).call

      expect(drives.map { [it.started_at.strftime('%H:%M'), it.ended_at.strftime('%H:%M')] }).to eq([['09:00', '09:30']])
    end
  end

  # The odometer read a drive while the car charged
  context 'with a drive within a recorded charge' do
    let(:readings) { [[at(9, 30), 100], [at(9, 45), 102]] }

    it 'keeps a mark at the end of the charge' do
      drive = described_class.new(readings, charges: [[at(9), at(10)]]).call.sole

      expect([drive.started_at, drive.ended_at, drive.within_charge]).to eq([nil, at(10), true])
    end
  end

  context 'with a longer pause between two drives' do
    let(:readings) { [[at(9), 100], [at(9, 30), 110], [at(10, 15), 110], [at(10, 30), 120]] }

    it 'keeps them apart' do
      expect(spans).to eq([['09:00', '09:30', 10], ['10:15', '10:30', 10]])
    end
  end
end
