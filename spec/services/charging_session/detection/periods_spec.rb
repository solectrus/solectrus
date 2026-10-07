describe ChargingSession::Detection::Periods do
  subject(:periods) { described_class.new(day, power:, connected:).call }

  let(:day) { Date.new(2026, 6, 10) }
  let(:connected) { [] }

  def at(hour, min = 0) = day.in_time_zone.change(hour:, min:)

  # A curve of 5-minute buckets, each stamped with its end. The given
  # periods have the value, all other buckets of the day have 0.
  def curve(*periods, value: 1)
    (1..288).map do |index|
      stamp = day.in_time_zone + (index * 5).minutes
      [stamp, periods.any? { |from, to| stamp > from && stamp <= to } ? value : 0]
    end
  end

  context 'with a gap of GAP' do
    let(:power) { curve([at(8), at(9)], [at(9, 15), at(10)], value: 11_000) }

    it 'finds one period' do
      expect(periods).to eq([[at(8), at(10)]])
    end
  end

  context 'with a longer gap' do
    let(:power) { curve([at(8), at(9)], [at(9, 20), at(10)], value: 11_000) }

    it 'finds two periods' do
      expect(periods).to eq([[at(8), at(9)], [at(9, 20), at(10)]])
    end

    context 'when the car stays connected' do
      let(:connected) { curve([at(7, 55), at(10, 5)]) }

      it 'finds one period' do
        expect(periods).to eq([[at(8), at(10)]])
      end
    end

    context 'when the car is connected only for a part of the gap' do
      let(:connected) { curve([at(7, 55), at(9, 10)]) }

      it 'finds two periods' do
        expect(periods.size).to eq(2)
      end
    end

    context 'when the connection has no reading in the gap' do
      let(:connected) { curve([at(7, 55), at(10, 5)]).reject { |time, _| time > at(9) && time <= at(9, 20) } }

      it 'finds two periods' do
        expect(periods.size).to eq(2)
      end
    end
  end

  context 'with a connection before the power' do
    let(:power) { curve([at(8), at(9)], value: 11_000) }
    let(:connected) { curve([at(6), at(12)]) }

    it 'keeps the ends of the power' do
      expect(periods).to eq([[at(8), at(9)]])
    end
  end

  context 'with power at midnight' do
    let(:power) { curve([at(0), at(1)], [at(23), day.next_day.in_time_zone], value: 3_600) }

    it 'ends each period inside the day' do
      expect(periods).to eq([[at(0), at(1)], [at(23), Timeframe.new(day.iso8601).ending]])
    end
  end
end
