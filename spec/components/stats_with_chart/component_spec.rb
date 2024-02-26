describe StatsWithChart::Component, type: :component do
  subject(:component) { described_class.new(sensor:, timeframe:) }

  let(:sensor) { 'inverter_power' }

  context 'when timeframe is a day' do
    let(:timeframe) { Timeframe.new '2022-01-22' }

    it 'is configured to switch to next day' do
      expect(component.boundary).to eq('2022-01-23T00:00:00+01:00')
      expect(component.forced_next_timeframe.to_s).to eq('2022-01-23')
    end
  end

  context 'when timeframe is a month' do
    let(:timeframe) { Timeframe.new '2022-01' }

    it 'is configured to switch to next month' do
      expect(component.boundary).to eq('2022-02-01T00:00:00+01:00')
      expect(component.forced_next_timeframe.to_s).to eq('2022-02')
    end
  end
end
