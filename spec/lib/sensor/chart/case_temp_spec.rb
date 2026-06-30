describe Sensor::Chart::CaseTemp do
  subject(:chart) { described_class.new(timeframe:) }

  def y_scale
    chart.__send__(:y_scale_options)
  end

  context 'with a monthly timeframe (bar view)' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    context 'when the temperature span is smaller than the minimum span' do
      before do
        create_summary(
          date: '2025-03-03',
          values: [[:case_temp, :min, 28], [:case_temp, :max, 30]],
        )
        create_summary(
          date: '2025-03-07',
          values: [[:case_temp, :min, 30], [:case_temp, :max, 32]],
        )
      end

      it 'pins a hard Y-axis widened to the minimum span and rounded' do
        # Data spans 28..32 (4 degrees), padded to 25..35 to reach the minimum
        # span of 10, then rounded outward to the nice 2-step grid -> 24..36.
        # Hard min/max are required because Chart.js bars would otherwise pull
        # the floor down to zero.
        expect(y_scale).to include(min: 24, max: 36)
        expect(y_scale[:ticks]).to include(stepSize: 2, maxTicksLimit: 7)
        expect(y_scale).not_to include(:suggestedMin, :suggestedMax)
      end
    end

    context 'when the temperature span exceeds the minimum span' do
      before do
        create_summary(
          date: '2025-03-03',
          values: [[:case_temp, :min, 24.6], [:case_temp, :max, 37.8]],
        )
      end

      it 'rounds the hard Y-axis outward to a clean grid' do
        # Raw data 24.6..37.8 rounds to the nice 2-step grid 24..38
        expect(y_scale).to include(min: 24, max: 38)
        expect(y_scale[:ticks]).to include(stepSize: 2, maxTicksLimit: 8)
      end
    end
  end

  context 'with a daily timeframe (line view)' do
    let(:timeframe) { Timeframe.new(Date.current.iso8601) }

    it 'leaves the bounds as soft suggestions so the axis can still grow' do
      # No hard min/max on the live/day line view
      expect(y_scale).to include(:suggestedMin, :suggestedMax)
      expect(y_scale).not_to include(:min, :max)
    end
  end

  context 'without any data' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    it 'leaves the Y-axis to Chart.js auto-scaling' do
      expect(y_scale).to include(suggestedMin: nil, suggestedMax: nil)
    end
  end
end
