describe Sensor::Chart::CustomPower do
  subject(:chart) do
    described_class.new(
      timeframe: Timeframe.new('2025-03-03'),
      sensor_name: :custom_power_01,
    )
  end

  describe '#fill_gaps_with_zero?' do
    it 'is enabled (a consumer reads 0 W while idle)' do
      expect(chart.__send__(:fill_gaps_with_zero?)).to be(true)
    end
  end

  describe '#gap_bridge_limit' do
    it 'disables bridging for aggregated views (every empty bucket is a real idle phase)' do
      day_chart =
        described_class.new(
          timeframe: Timeframe.new('2025-03-03'),
          sensor_name: :custom_power_01,
        )
      expect(day_chart.__send__(:gap_bridge_limit)).to eq(0)
    end

    it 'bridges only cadence jitter in the live "now" view (issue #5567)' do
      now_chart =
        described_class.new(timeframe: Timeframe.now, sensor_name: :custom_power_01)
      expect(now_chart.__send__(:gap_bridge_limit)).to eq(2.minutes.in_milliseconds)
    end
  end

  describe '#span_gaps' do
    it 'collapses a zero bridge limit to false, not 0 (Chart.js breaks the line at every point on 0)' do
      day_chart =
        described_class.new(
          timeframe: Timeframe.new('2025-03-03'),
          sensor_name: :custom_power_01,
        )
      expect(day_chart.__send__(:span_gaps)).to be(false)
    end

    it 'passes the positive cadence-jitter limit through in the "now" view' do
      now_chart =
        described_class.new(timeframe: Timeframe.now, sensor_name: :custom_power_01)
      expect(now_chart.__send__(:span_gaps)).to eq(2.minutes.in_milliseconds)
    end
  end

  describe '#fill_gaps_with_zero' do
    it 'collapses a leading nil run to 0' do
      expect(chart.__send__(:fill_gaps_with_zero, [nil, nil, 50, 60])).to eq(
        [0, 0, 50, 60],
      )
    end

    it 'collapses a trailing nil run to 0' do
      expect(chart.__send__(:fill_gaps_with_zero, [50, 60, nil, nil])).to eq(
        [50, 60, 0, 0],
      )
    end

    it 'collapses a long interior idle gap to 0' do
      expect(chart.__send__(:fill_gaps_with_zero, [50, nil, nil, 60])).to eq(
        [50, 0, 0, 60],
      )
    end

    it 'collapses an all-nil dataset to 0 (consumer off for the whole window)' do
      expect(chart.__send__(:fill_gaps_with_zero, [nil, nil, nil])).to eq(
        [0, 0, 0],
      )
    end

    it 'keeps existing values, including a real 0' do
      expect(chart.__send__(:fill_gaps_with_zero, [0, 50, nil])).to eq(
        [0, 50, 0],
      )
    end
  end

  # End-to-end gap handling in the live "now" view (30s buckets).
  describe '#process_gaps' do
    subject(:now_chart) do
      described_class.new(timeframe: Timeframe.now, sensor_name: :custom_power_01)
    end

    # 30s-spaced timestamps, matching the "now" view bucket grid
    def labels(count)
      Array.new(count) { |i| i * 30.seconds.in_milliseconds }
    end

    it 'bridges a cadence gap so constant power does not drop to 0 (issue #5567)' do
      # A consumer polled every ~28s occasionally misses a single 30s bucket;
      # the bracketing samples show the same constant power.
      result = now_chart.__send__(:process_gaps, labels(3), [40, nil, 40])
      expect(result).to eq([40, 40.0, 40])
    end

    it 'collapses a long idle gap to 0 instead of bridging it' do
      # 8 missing buckets = 4 min, well over the 2-min cadence-jitter limit
      gap = [nil] * 8
      result = now_chart.__send__(:process_gaps, labels(gap.size + 2), [40, *gap, 40])
      expect(result).to eq([40, *([0] * 8), 40])
    end

    it 'collapses a leading idle gap to 0 (consumer off at the window start)' do
      # The fridge was idle before its first compressor cycle; that leading
      # off-phase renders as a flat 0 baseline, like any interior idle phase.
      result = now_chart.__send__(:process_gaps, labels(4), [nil, nil, 40, 40])
      expect(result).to eq([0, 0, 40, 40])
    end

    it 'respects an explicit gap_bridge_limit of 0 even with many real samples' do
      # day-view base limit is 0 (explicit no-bridge override). Even when the
      # series has enough samples for the adaptive cadence detector to fire,
      # the explicit 0 must win and gaps must collapse to 0 (per
      # fill_gaps_with_zero?).
      day_chart =
        described_class.new(
          timeframe: Timeframe.new('2025-03-03'),
          sensor_name: :custom_power_01,
        )

      values = [40, 40, 40, 40, 40, nil, nil, 40, 40, 40]
      day_labels = Array.new(values.size) { |i| i * 5.minutes.in_milliseconds }
      result = day_chart.__send__(:process_gaps, day_labels, values)

      expect(result).to eq([40, 40, 40, 40, 40, 0, 0, 40, 40, 40])
    end
  end
end
