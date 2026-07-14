describe Sensor::Chart::GridCosts do
  subject(:chart) { described_class.new(timeframe:) }

  # For short timeframes the values come from Sensor::Query::Series, which turns
  # power into money per data point (Influx::FinanceCalculation).
  describe 'for a short timeframe' do
    let(:timeframe) { Timeframe.now }

    before do
      freeze_time

      add_influx_point(
        name: Sensor::Config.measurement(:grid_import_power),
        fields: {
          Sensor::Config.field(:grid_import_power) => 500.0,
        },
        time: 30.minutes.ago,
      )

      allow(Price).to receive(:at).with(
        hash_including(name: :electricity),
      ).and_return(BigDecimal('0.4'))
    end

    it 'converts the grid import power to costs per hour' do
      values = chart.data[:datasets].first[:data].compact

      # 500 W * 0.4 / 1000 = 0.20
      expect(values).to all(be_within(0.0001).of(0.2))
    end

    it 'produces Float values' do
      values = chart.data[:datasets].first[:data].compact

      expect(values).to all(be_a(Float))
    end
  end
end
