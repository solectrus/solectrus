describe Car::DayTimeline::OffsiteEstimate do
  # The session started at 9:00, and the day has data up to its end
  subject(:estimate) { described_class.new(from: at(9), to: at(0) + 1.day, soc:, plug:, drives:, charges:).call&.map { it.strftime('%H:%M') } }

  let(:soc) { [] }
  let(:plug) { [] }
  let(:drives) { [] }
  let(:charges) { [] }

  def at(hour, minute = 0) = Time.zone.local(2026, 6, 15, hour, minute)

  context 'without a sign' do
    it 'charges over the whole time' do
      expect(estimate).to eq(%w[09:00 00:00])
    end

    context 'with a drive' do
      let(:drives) { [[at(10), at(11)], [at(12), at(17)]] }

      it 'charges in the longest time without a drive' do
        expect(estimate).to eq(%w[17:00 00:00])
      end
    end
  end

  context 'with a rise of the state of charge' do
    let(:soc) { [[at(8), 40], [at(11), 40], [at(12), 70], [at(14), 70]] }
    # The car is plugged in all day, which the rise beats
    let(:plug) { [[at(0), 1.0]] }

    it 'follows the rise' do
      expect(estimate).to eq(%w[11:00 12:00])
    end

    context 'with noise' do
      let(:soc) { [[at(8), 40], [at(11), 40], [at(12), 70], [at(20), 70], [at(20, 15), 71], [at(20, 30), 70]] }

      it 'leaves it out' do
        expect(estimate).to eq(%w[11:00 12:00])
      end
    end

    # The state of charge rose at another charger too
    context 'with a small rise far from the charge' do
      let(:soc) { [[at(8), 40], [at(11), 40], [at(12), 70], [at(20), 70], [at(20, 15), 72], [at(21), 72]] }

      it 'charges in the run with the most rise' do
        expect(estimate).to eq(%w[11:00 12:00])
      end
    end

    context 'with a slow charge in steps of 1 %' do
      let(:soc) { [[at(8), 40], [at(20), 40], [at(20, 15), 41], [at(20, 30), 41], [at(20, 45), 42]] }

      it 'keeps it' do
        expect(estimate).to eq(%w[20:00 20:45])
      end
    end

    # The main rise lies before the start of the session
    context 'with the main rise before the start' do
      let(:soc) { [[at(6), 40], [at(7), 70], [at(20), 70], [at(20, 15), 72], [at(21), 72]] }

      it 'charges in the rise after the start' do
        expect(estimate).to eq(%w[20:00 20:15])
      end
    end
  end

  context 'with the plug' do
    let(:plug) { [[at(10), 1.0], [at(13), 0.0]] }

    it 'charges in the time plugged in' do
      expect(estimate).to eq(%w[10:00 13:00])
    end

    context 'with a drive while plugged in' do
      let(:drives) { [[at(12), at(12, 30)]] }

      it 'charges in the longer time without the drive' do
        expect(estimate).to eq(%w[10:00 12:00])
      end
    end
  end

  context 'with another session of the car' do
    let(:charges) { [[at(18), at(20)]] }

    it 'leaves out its time' do
      expect(estimate).to eq(%w[09:00 18:00])
    end

    # The readings come every 15 minutes, so the rise of the other session
    # starts before it
    context 'with a rise that reaches into it' do
      let(:soc) { [[at(11), 40], [at(12), 60], [at(17, 50), 60], [at(18, 5), 65], [at(20), 80]] }

      it 'leaves out the whole rise' do
        expect(estimate).to eq(%w[11:00 12:00])
      end
    end
  end

  context 'without time' do
    it 'has no charge' do
      expect(described_class.new(from: at(10), to: at(10)).call).to be_nil
    end
  end
end
