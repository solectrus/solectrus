describe Car::DayTimeline::Plugged do
  subject(:plugged) { described_class.new(points, ends_at: at(23, 55), charges:, drives:).call.map { |from, to| [from.strftime('%H:%M'), to.strftime('%H:%M')] } }

  let(:charges) { [] }
  let(:drives) { [] }

  def at(hour, minute = 0) = Time.zone.local(2026, 10, 10, hour, minute)

  context 'with a plug from the night before' do
    let(:points) { [[at(0), 1.0], [at(7), 0.0], [at(18), 1.0]] }

    it 'holds each state until the next reading, the last one until the end' do
      expect(plugged).to eq([%w[00:00 07:00], %w[18:00 23:55]])
    end
  end

  context 'with a charge in the time' do
    let(:points) { [[at(18), 1.0], [at(18, 5), 1.0]] }
    let(:charges) { [[at(19), at(21)]] }

    it 'leaves out the charge, which has a bar of its own' do
      expect(plugged).to eq([%w[18:00 19:00], %w[21:00 23:55]])
    end
  end

  # The car reports that it was unplugged after the drive
  context 'with a drive in the time' do
    let(:points) { [[at(0), 1.0], [at(7, 15), 0.0]] }
    let(:drives) { [[at(7), at(8, 15)]] }

    it 'ends where the drive starts' do
      expect(plugged).to eq([%w[00:00 07:00]])
    end

    # Nothing tells when the drive started
    context 'without a start' do
      let(:drives) { [[at(7), at(7)]] }

      it 'ends at the end of the drive' do
        expect(plugged).to eq([%w[00:00 07:00]])
      end
    end

    context 'with the report after the end of the drive' do
      let(:points) { [[at(0), 1.0], [at(8, 25), 0.0]] }

      it 'ends where the drive starts' do
        expect(plugged).to eq([%w[00:00 07:00]])
      end
    end
  end

  # The plug reports a minute before the session starts
  context 'with a rest below a bucket' do
    let(:points) { [[at(18, 59), 1.0]] }
    let(:charges) { [[at(19), at(23, 55)]] }

    it 'leaves it out' do
      expect(plugged).to be_empty
    end
  end
end
