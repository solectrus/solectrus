describe Heatpump::SensorKpiLink::Component, type: :component do
  subject(:component) do
    described_class.new(
      data: Sensor::Data::Single.new({ outdoor_temp: 17.5 }, timeframe:),
      sensor_name: :outdoor_temp,
      timeframe:,
      chart_url: '/chart',
      url: '/heatpump',
    )
  end

  context 'with a timeframe in the past' do
    let(:timeframe) { Timeframe.new('2026-09') }

    it 'opens the insights on a long press' do
      render_inline(component)

      link = page.find('a')
      expect(link['data-controller']).to eq('tooltip')
      expect(link['data-tooltip-touch-value']).to eq('long')
      expect(link['data-tooltip-sheet-url-value']).to eq('/insights/outdoor_temp/2026-09')
    end
  end

  context 'with the current values' do
    let(:timeframe) { Timeframe.now }

    it 'has no insights to open' do
      render_inline(component)

      expect(page.find('a')['data-controller']).to be_nil
    end
  end
end
