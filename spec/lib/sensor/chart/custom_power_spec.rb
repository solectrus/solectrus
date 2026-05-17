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

  describe '#bridge_gaps?' do
    it 'is disabled for aggregated views (every empty bucket is a real idle phase)' do
      day_chart =
        described_class.new(
          timeframe: Timeframe.new('2025-03-03'),
          sensor_name: :custom_power_01,
        )
      expect(day_chart.__send__(:bridge_gaps?)).to be(false)
    end

    it 'is enabled for the live "now" view (smooths cadence gaps, issue #5552)' do
      now_chart =
        described_class.new(timeframe: Timeframe.now, sensor_name: :custom_power_01)
      expect(now_chart.__send__(:bridge_gaps?)).to be(true)
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
end
