describe Sensor::Chart::CarBatterySoc do
  let(:chart) { described_class.new(timeframe:) }
  let(:timeframe) { Timeframe.new('P1H') }
  let(:max_age) { Sensor::Registry[:car_battery_soc].max_age }

  def minute_labels(count)
    start = Time.zone.local(2025, 3, 3, 10, 0, 0)
    Array.new(count) { |i| (start + i.minutes).to_i * 1000 }
  end

  describe '#series_lookback' do
    it 'looks back one max_age to seed the leading edge' do
      expect(chart.__send__(:series_lookback)).to eq(max_age)
    end
  end

  describe '#gap_bridge_limit' do
    it 'bridges gaps up to the sensor max_age' do
      expect(chart.__send__(:gap_bridge_limit)).to eq(max_age.in_milliseconds)
    end
  end

  describe '#bridge_short_gaps' do
    it 'bridges a sparse 30-min gap as a flat step, holding the last value' do
      gap = [nil] * 29 # 30 min between the two samples
      labels = minute_labels(gap.size + 2)
      result = chart.__send__(:bridge_short_gaps, labels, [40.0, *gap, 46.0])

      # Step, not ramp: the value holds at 40 until the next sample jumps to 46.
      expect(result).to eq([40.0, *([40.0] * 29), 46.0])
    end

    it 'leaves an outage beyond max_age as a fully visible gap' do
      gap = [nil] * 150 # 151 min > 2h max_age
      labels = minute_labels(gap.size + 2)
      result = chart.__send__(:bridge_short_gaps, labels, [40.0, *gap, 46.0])

      expect(result).to eq([40.0, *gap, 46.0])
    end

    it 'leaves trailing nulls untouched, so the live updater fills the edge' do
      labels = minute_labels(4)
      result = chart.__send__(:bridge_short_gaps, labels, [40.0, 46.0, nil, nil])

      expect(result).to eq([40.0, 46.0, nil, nil])
    end
  end

  describe '#process_gaps' do
    context 'when on the live (now) view' do
      let(:timeframe) { Timeframe.now }

      it 'carries the last value forward to the window edge to meet the live tail' do
        labels = minute_labels(4)
        result = chart.__send__(:process_gaps, labels, [40.0, 46.0, nil, nil])

        expect(result).to eq([40.0, 46.0, 46.0, 46.0])
      end
    end

    context 'when on a historical view' do
      let(:timeframe) { Timeframe.new('day') }

      it 'leaves the trailing edge as a gap (no value dragged to now)' do
        labels = minute_labels(4)
        result = chart.__send__(:process_gaps, labels, [40.0, 46.0, nil, nil])

        expect(result).to eq([40.0, 46.0, nil, nil])
      end
    end
  end

  describe '#style_for_sensor' do
    it 'renders the line as steps' do
      style = chart.__send__(:style_for_sensor, Sensor::Registry[:car_battery_soc])
      expect(style[:stepped]).to be(true)
    end
  end
end
