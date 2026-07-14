describe Sensor::Chart::Savings do
  subject(:chart) { described_class.new(timeframe:) }

  # A custom consumer excluded from house_power is subtracted from house_power,
  # so the calculation must add it back -- otherwise its consumption is missing
  # from the comparison price (traditional costs) and the savings come out too
  # low.
  describe 'with a custom consumer excluded from house_power' do
    include_context 'with an excluded custom consumer'

    let(:timeframe) { Timeframe.now }

    before do
      freeze_time

      influx_batch do
        {
          house_power: 800.0, # raw, still contains custom_power_01
          heatpump_power: 300.0,
          custom_power_01: 200.0,
          grid_import_power: 500.0,
          grid_export_power: 100.0,
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

      # BigDecimal, like the real Price.at (decimal column)
      allow(Price).to receive(:at).with(
        hash_including(name: :electricity),
      ).and_return(BigDecimal('0.4'))
      allow(Price).to receive(:at).with(hash_including(name: :feed_in)).and_return(
        BigDecimal('0.1'),
      )
    end

    # house_power is reduced by the excluded consumer (800 - 200 = 600), so the
    # traditional costs have to add it back to cover the full consumption:
    #   traditional costs: (600 + 300 + 200) * 0.4 / 1000 = 0.44
    #   solar price:        500 * 0.4 / 1000 - 100 * 0.1 / 1000 = 0.19
    # Without the excluded consumer they would be (600 + 300) * 0.4 / 1000 =
    # 0.36, and the savings would come out too low (0.17).
    it 'counts the excluded consumer towards the savings' do
      values = chart.data[:datasets].first[:data].compact

      expect(values).to all(be_within(0.0001).of(0.25))
    end

    # A BigDecimal would be serialized as a JSON string, but the Chart.js
    # datasets are numbers
    it 'produces Float values' do
      values = chart.data[:datasets].first[:data].compact

      expect(values).to all(be_a(Float))
    end
  end
end
