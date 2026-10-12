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

    it 'charts the sum as one bar while the tariff has no base fee' do
      datasets = chart.data[:datasets]

      expect(datasets.length).to eq(1)
      expect(datasets.first[:id]).to eq('grid_costs')
      expect(datasets.first[:stack]).to be_nil
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

      it 'splits the bar into base fee and energy costs' do
        base_fee, energy_costs = chart.data[:datasets]

        expect(base_fee[:id]).to eq('grid_base_fee')
        expect(energy_costs[:id]).to eq('grid_energy_costs')
      end

      it 'stacks both segments onto one bar' do
        stacks = chart.data[:datasets].pluck(:stack)

        expect(stacks).to all(eq('GridCosts'))
      end

      it 'labels the segments with their short names' do
        labels = chart.data[:datasets].pluck(:label)

        expect(labels).to eq(
          [
            Sensor::Registry[:grid_base_fee].display_name(:short),
            Sensor::Registry[:grid_energy_costs].display_name(:short),
          ],
        )
      end

      it 'charts the energy costs unchanged next to the fee' do
        energy_costs = chart.data[:datasets].second[:data].compact

        # 500 W * 0.4 / 1000 = 0.20, the fee rides on its own segment
        expect(energy_costs).to all(be_within(0.0001).of(0.2))
      end
    end
  end
end
