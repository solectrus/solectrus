describe Car::DayTimeline::SocLine do
  subject(:line) { described_class.new(points, ends_at:, drives:, charges:).call }

  let(:ends_at) { at(23, 55) }
  let(:drives) { [] }
  let(:charges) { [] }

  def at(hour, minute = 0) = Time.zone.local(2026, 10, 10, hour, minute)

  # Each piece as [from, to, from_value, to_value, known], the times as "HH:MM"
  def pieces = line.map { [it.from.strftime('%H:%M'), it.to.strftime('%H:%M'), it.from_value, it.to_value, it.known] }

  context 'with close readings' do
    let(:points) { [[at(9), 80], [at(9, 15), 78], [at(9, 30), 78]] }

    it 'holds each value in one piece and steps at the next reading' do
      expect(pieces).to eq(
        [
          ['09:00', '09:15', 80, 80, true],
          ['09:15', '09:15', 80, 78, true],
          ['09:15', '23:55', 78, 78, true],
        ],
      )
    end
  end

  # The car reported after the drive and after the charge
  context 'with readings far apart' do
    let(:points) { [[at(0), 62], [at(12, 25), 40], [at(17, 15), 67]] }
    let(:drives) { [[at(12, 20), at(12, 20)]] }
    let(:charges) { [[at(12, 20), at(14, 50)]] }

    it 'falls on the drive and rises on the charge, as estimates' do
      expect(pieces).to eq(
        [
          ['00:00', '12:20', 62, 62, true],
          ['12:20', '12:20', 62, 40, false],
          ['12:20', '12:25', 40, 40, true],
          ['12:25', '14:50', 40, 67, false],
          ['14:50', '23:55', 67, 67, true],
        ],
      )
    end
  end

  # The car reported the end of the charge only after the next drive began
  context 'with close readings and a late report of a charge' do
    let(:points) { [[at(19, 20), 69], [at(20, 20), 80]] }
    let(:charges) { [[at(18, 8), at(19, 35)]] }
    let(:drives) { [[at(19, 35), at(20, 20), 1]] }

    it 'steps at the end of the charge' do
      expect(pieces.first(3)).to eq([['19:20', '19:35', 69, 69, true], ['19:35', '19:35', 69, 80, true], ['19:35', '23:55', 80, 80, true]])
    end
  end

  # A charge that paused until the cheap tariff of the night
  context 'with readings far apart and a charge with a pause' do
    let(:points) { [[at(19), 30], [at(23, 50), 80]] }
    let(:charges) { [[at(20), at(21)], [at(22), at(23)]] }

    it 'rises in the parts of the charge and holds in the pause' do
      expect(pieces).to eq(
        [
          ['19:00', '20:00', 30, 30, true],
          ['20:00', '21:00', 30, 55.0, false],
          ['21:00', '22:00', 55.0, 55.0, false],
          ['22:00', '23:00', 55.0, 80, false],
          ['23:00', '23:55', 80, 80, true],
        ],
      )
    end
  end

  # A short drive with a start, and a long one whose start nothing tells
  context 'with readings far apart and two drives' do
    let(:points) { [[at(9), 80], [at(17), 40]] }
    let(:drives) { [[at(10), at(10, 40), 10], [at(16), at(16), 30]] }

    it 'falls by the distance of each drive' do
      expect(pieces.first(4)).to eq(
        [
          ['09:00', '10:00', 80, 80, true],
          ['10:00', '10:40', 80, 70.0, false],
          ['10:40', '16:00', 70.0, 70.0, false],
          ['16:00', '16:00', 70.0, 40, false],
        ],
      )
    end
  end

  # The reading at 11:00 holds half of the first drive
  context 'with readings far apart and a drive into the gap' do
    let(:points) { [[at(9), 80], [at(11), 60], [at(14), 30]] }
    let(:drives) { [[at(10), at(12), 40], [at(13), at(13, 30), 20]] }

    it 'falls by the part of the distance in the gap' do
      expect(pieces[2..5]).to eq(
        [
          ['11:00', '12:00', 60, 45.0, false],
          ['12:00', '13:00', 45.0, 45.0, false],
          ['13:00', '13:30', 45.0, 30, false],
          ['13:30', '23:55', 30, 30, true],
        ],
      )
    end
  end

  # The reading at the start of the gap holds the drive
  context 'with readings far apart and a drive that ends at the first' do
    let(:points) { [[at(8), 60], [at(18), 40]] }
    let(:drives) { [[at(7), at(8), 5]] }

    it 'leaves open when it changed' do
      expect(pieces.first).to eq(['08:00', '18:00', 60, 40, false])
    end
  end

  context 'with readings far apart and charges that overlap' do
    let(:points) { [[at(9), 40], [at(13), 70]] }
    let(:charges) { [[at(10), at(12)], [at(11), at(11, 30)]] }

    it 'rises once over their time' do
      expect(pieces.first(2)).to eq([['09:00', '10:00', 40, 40, true], ['10:00', '12:00', 40, 70, false]])
    end
  end

  context 'with readings far apart and nothing that explains the change' do
    let(:points) { [[at(0), 62], [at(12, 25), 40]] }

    it 'leaves open when it changed' do
      expect(pieces.first).to eq(['00:00', '12:25', 62, 40, false])
    end
  end

  # A cold battery reads one point less
  context 'with a change of one point' do
    let(:points) { [[at(0), 62], [at(12, 25), 61]] }

    it 'steps at the reading' do
      expect(pieces.first(2)).to eq([['00:00', '12:25', 62, 62, true], ['12:25', '12:25', 62, 61, true]])
    end
  end
end
