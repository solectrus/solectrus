describe Sensor::Chart::CarBatterySoc do
  let(:chart) { described_class.new(timeframe:, cars: [Car.new(id: 1, active_from: Date.new(2020, 1, 1))]) }
  let(:timeframe) { Timeframe.new('P1H') }

  def minute_labels(count)
    start = Time.zone.local(2025, 3, 3, 10, 0, 0)
    Array.new(count) { |i| (start + i.minutes).to_i * 1000 }
  end

  # The state of charge is a state, which holds until its next reading
  describe '#holds_value?' do
    it 'is true' do
      expect(chart.__send__(:holds_value?)).to be(true)
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

    # A source like TeslaMate sends only a change, so a parked car is quiet
    it 'holds the value over hours without a reading' do
      gap = [nil] * 600 # 10 hours
      labels = minute_labels(gap.size + 2)
      result = chart.__send__(:bridge_short_gaps, labels, [40.0, *gap, 46.0])

      expect(result).to eq([40.0, *([40.0] * 600), 46.0])
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
        result = chart.__send__(:process_gaps, labels, [40.0, 46.0, nil, nil], :car_battery_soc_1)

        expect(result).to eq([40.0, 46.0, 46.0, 46.0])
      end
    end

    context 'when on a past day' do
      let(:timeframe) { Timeframe.new('2025-03-03') }

      it 'holds the last value up to the end of the day' do
        labels = minute_labels(4)
        result = chart.__send__(:process_gaps, labels, [40.0, 46.0, nil, nil], :car_battery_soc_1)

        expect(result).to eq([40.0, 46.0, 46.0, 46.0])
      end

      it 'starts with the last reading before the day' do
        influx_batch do
          add_influx_point(
            name: Sensor::Config.measurement(:car_battery_soc_1),
            fields: { Sensor::Config.field(:car_battery_soc_1) => 33.0 },
            time: Time.zone.local(2025, 2, 20, 18),
          )
        end
        labels = minute_labels(4)
        result = chart.__send__(:process_gaps, labels, [nil, nil, 40.0, 46.0], :car_battery_soc_1)

        expect(result).to eq([33.0, 33.0, 40.0, 46.0])
      end
    end
  end

  describe '#style_for_sensor' do
    it 'renders the line as steps' do
      style = chart.__send__(:style_for_sensor, Sensor::Registry[:car_battery_soc_1])
      expect(style[:stepped]).to be(true)
    end
  end
end
