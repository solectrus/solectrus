describe Sensor::Chart::TotalCosts do
  subject(:chart) { described_class.new(timeframe:) }

  # For short timeframes the values come from Sensor::Query::Series, which turns
  # power into money per data point (Influx::FinanceCalculation).
  describe 'for a short timeframe' do
    let(:timeframe) { Timeframe.now }

    before do
      freeze_time

      influx_batch do
        {
          grid_import_power: 500.0,
          # inverter_power itself is calculated from the configured strings
          inverter_power_1: 2000.0,
          grid_export_power: 800.0,
        }.each do |sensor, value|
          add_influx_point(
            name: Sensor::Config.measurement(sensor),
            fields: {
              Sensor::Config.field(sensor) => value,
            },
            time: 30.minutes.ago,
          )
        end
      end

      allow(Price).to receive(:at).with(
        hash_including(name: :electricity),
      ).and_return(BigDecimal('0.4'))
      allow(Price).to receive(:at).with(hash_including(name: :feed_in)).and_return(
        BigDecimal('0.1'),
      )
    end

    # grid costs:        500 * 0.4 / 1000 = 0.20
    # opportunity costs: (2000 - 800) * 0.1 / 1000 = 0.12
    it 'adds grid costs and opportunity costs' do
      values = chart.data[:datasets].first[:data].compact

      expect(values).to all(be_within(0.0001).of(0.32))
    end

    it 'produces Float values' do
      values = chart.data[:datasets].first[:data].compact

      expect(values).to all(be_a(Float))
    end
  end
end
