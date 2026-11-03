describe Car::DayTimeline::StaleReadings do
  subject(:stale) { described_class.new(odometer:, soc:, plug:).call.map { |from, to| [from.strftime('%H:%M'), to.strftime('%H:%M')] } }

  let(:plug) { [] }

  def at(hour, minute = 0) = Time.zone.local(2026, 10, 10, hour, minute)

  # Every 15 minutes from 08:00 to 10:30
  def times = (0..10).map { at(8) + (it * 15).minutes }

  # The car sent its state of 08:00 until it reported a drive and a charge at
  # once
  context 'with a state that stood still up to a rise faster than a car drives' do
    let(:odometer) { [*times.map { [it, 100.0] }, [at(10, 45), 210.0]] }
    let(:soc) { [*times.map { [it, 24.0] }, [at(10, 45), 63.0]] }

    it 'repeats the state after its first reading' do
      expect(stale).to eq([%w[08:00 10:45]])
    end

    context 'with a change of the plug' do
      let(:plug) { [[at(8), 0.0], [at(9), 1.0]] }

      it 'repeats the state after the change' do
        expect(stale).to eq([%w[09:00 10:45]])
      end
    end

    context 'with a change of the state of charge by SOC_NOISE' do
      let(:soc) { [*times.map { [it, 24.0] }, [at(10, 45), 23.0]] }

      it 'keeps the readings' do
        expect(stale).to be_empty
      end
    end
  end

  # The odometer reports the drive late, but the state of charge fell
  context 'with a state of charge that fell before the rise' do
    let(:odometer) { [*times.map { [it, 100.0] }, [at(10, 45), 160.0]] }
    let(:soc) { times.each_with_index.map { |time, index| [time, 80.0 - [index, 5].min] } << [at(10, 45), 75.0] }

    it 'keeps the readings' do
      expect(stale).to be_empty
    end
  end

  context 'with a rise that fits the time' do
    let(:odometer) { [*times.map { [it, 100.0] }, [at(10, 45), 120.0]] }
    let(:soc) { [*times.map { [it, 24.0] }, [at(10, 45), 20.0]] }

    it 'keeps the readings' do
      expect(stale).to be_empty
    end
  end

  context 'without readings before the rise' do
    let(:odometer) { [[at(8), 100.0], [at(8, 15), 210.0]] }
    let(:soc) { [[at(8), 24.0], [at(8, 15), 63.0]] }

    it 'has nothing to leave out' do
      expect(stale).to be_empty
    end
  end
end
