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
    it 'stacks grid costs and opportunity costs' do
      grid_costs, opportunity_costs = chart.data[:datasets]

      expect(grid_costs[:id]).to eq('grid_costs')
      expect(opportunity_costs[:id]).to eq('opportunity_costs')

      # The segments share one timestamp grid, so they are read in pairs. Only
      # the grid side reports a gap as nil: opportunity_costs counts a missing
      # reading as no self-consumption, which is zero rather than unknown.
      pairs =
        grid_costs[:data]
          .zip(opportunity_costs[:data])
          .reject { |grid, _pv| grid.nil? }

      expect(pairs).to be_present
      expect(pairs.map(&:first)).to all(be_within(0.0001).of(0.2))
      expect(pairs.map(&:second)).to all(be_within(0.0001).of(0.12))
    end

    it 'stacks every segment onto one bar' do
      stacks = chart.data[:datasets].pluck(:stack)

      expect(stacks).to all(eq('TotalCosts'))
    end

    it 'produces Float values' do
      values =
        chart.data[:datasets].flat_map { |dataset| dataset[:data] }.compact

      expect(values).to all(be_a(Float))
    end

    context 'with a base fee' do
      before do
        Price.delete_all
        Price.electricity.create!(
          starts_at: 1.year.ago.to_date,
          amount_per_kwh: 0.4,
          amount_per_month: 12,
        )
      end

      # The grid costs contribute their own split, so the bar carries the same
      # parts ConsumeDetails::Component breaks the sum into.
      it 'splits the grid side into base fee and energy costs' do
        base_fee, energy_costs, opportunity_costs = chart.data[:datasets]

        expect(base_fee[:id]).to eq('grid_base_fee')
        expect(energy_costs[:id]).to eq('grid_energy_costs')
        expect(opportunity_costs[:id]).to eq('opportunity_costs')
      end

      it 'keeps every segment on one stack' do
        stacks = chart.data[:datasets].pluck(:stack)

        expect(stacks).to all(eq('TotalCosts'))
      end
    end
  end
end
