describe ChargingSession::Detection::Periods do
  subject(:found) { described_class.new(day, power:, connected:, gaps:).call }

  # The periods without their parts
  let(:periods) { found.map { [it.from, it.to] } }

  let(:day) { Date.new(2026, 6, 10) }
  let(:connected) { [] }
  let(:gaps) { [] }

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

      it 'keeps the parts with power in the period' do
        expect(found.first.parts).to eq([[at(8), at(9)], [at(9, 20), at(10)]])
      end

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

  # A collector that fails sends no value, so its buckets have no reading
  # and are the gaps of the curve
  def without_data(curve, from, to) = curve.partition { |time, _| time <= from || time > to }

  context 'with a gap without data in a charge' do
    let(:power) { without_data(curve([at(8), at(9)], [at(10), at(11)], value: 11_000), at(9), at(10)).first }
    let(:gaps) { without_data(curve, at(9), at(10)).last }

    it 'finds one period' do
      expect(periods).to eq([[at(8), at(11)]])
    end
  end

  # The collector fails at 16:15 and sends 0 W at 17:10
  context 'with a gap without data at the end of a charge' do
    let(:power) { without_data(curve([at(16, 10), at(16, 15)], value: 20_000), at(16, 15), at(17, 5)).first }
    let(:gaps) { without_data(curve, at(16, 15), at(17, 5)).last }

    it 'ends the period at the next bucket with data' do
      expect(periods).to eq([[at(16, 10), at(17, 10)]])
    end
  end

  # The collector sends 0 W at 0:35 and the power of the charge at 2:05
  context 'with a gap without data at the start of a charge' do
    let(:power) { without_data(curve([at(2), at(3)], value: 5_600), at(0, 35), at(2)).first }
    let(:gaps) { without_data(curve, at(0, 35), at(2)).last }

    it 'starts the period at the last bucket with data' do
      expect(periods).to eq([[at(0, 30), at(3)]])
    end
  end

  # The connected car joins two parts over a pause with one bucket of 0 W
  # between buckets without data. Both parts reach across the buckets
  # without data to that bucket.
  context 'with one bucket of data in a pause without data' do
    def missing = [at(9, 5), at(9, 15), at(9, 20)]

    let(:power) { curve([at(8), at(9)], [at(9, 20), at(10)], value: 11_000).reject { it.first.in?(missing) } }
    let(:gaps) { missing.map { [it, 0.0] } }
    let(:connected) { curve([at(7, 55), at(10, 5)]) }

    it 'keeps the parts apart' do
      expect(found.sole.parts).to eq([[at(8), at(9, 5)], [at(9, 5), at(10)]])
    end
  end

  # The same curve with 0 W instead of the gap
  context 'with a pause of 0 W in a charge' do
    let(:power) { curve([at(8), at(9)], [at(10), at(11)], value: 11_000) }

    it 'finds two periods' do
      expect(periods).to eq([[at(8), at(9)], [at(10), at(11)]])
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
