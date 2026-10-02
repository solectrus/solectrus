describe Sensor::Chart::CarRange do
  subject(:chart) { described_class.new(timeframe:, car_number: 1) }

  describe '.supports?' do
    it 'draws the live view, hours and a day' do
      expect(
        [Timeframe.now, Timeframe.new('P1H'), Timeframe.new('2026-06-26')].map { described_class.supports?(it) },
      ).to all(be(true))
    end

    it 'does not draw a week, a month or a year' do
      expect(
        [Timeframe.new('2026-W26'), Timeframe.new('2026-06'), Timeframe.new('2026')].map do
          described_class.supports?(it)
        end,
      ).to all(be(false))
    end
  end

  context 'with a month' do
    let(:timeframe) { Timeframe.new('2026-06') }

    it 'has no data, because car_range_1 stores no daily value' do
      expect(chart.data).to be_nil
    end
  end

  context 'with the live view' do
    let(:timeframe) { Timeframe.now }

    it 'renders the line as steps' do
      style = chart.__send__(:style_for_sensor, Sensor::Registry[:car_range_1])
      expect(style[:stepped]).to be(true)
    end
  end
end
