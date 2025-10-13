describe Insights::HeatmapYearly do
  subject(:service) { described_class.new(sensor:, timeframe:) }

  let(:timeframe) { Timeframe.new('2023') }

  describe '#call' do
    subject(:call) { service.call }

    context 'with valid sensor and timeframe' do
      let(:sensor) { Sensor::Registry[:inverter_power] }

      before do
        create_summary(
          date: Date.new(2023, 1, 15),
          values: [[:inverter_power_1, :sum, 1000.0]],
        )
        create_summary(
          date: Date.new(2023, 2, 16),
          values: [[:inverter_power_1, :sum, 1200.0]],
        )
        create_summary(
          date: Date.new(2023, 2, 17),
          values: [[:inverter_power_1, :sum, 1500.0]],
        )
      end

      it 'returns a heatmap structure with months and days' do
        expect(call).to be_a(Hash)
        expect(call).to have_key(1)
        expect(call).to have_key(2)
        expect(call[1]).to be_a(Hash)
        expect(call[1][15]).to eq(1000)
        expect(call[2][16]).to eq(1200)
        expect(call[2][17]).to eq(1500)
      end

      it 'groups data by month and day correctly' do
        expect(call[1]).to include(15 => 1000)
        expect(call[2]).to include(16 => 1200, 17 => 1500)
      end
    end

    context 'with grid_power sensor' do
      let(:sensor) { Sensor::Registry[:grid_power] }

      before do
        # Create power data for grid calculations
        create_summary(
          date: Date.new(2023, 1, 15),
          values: [
            [:grid_export_power, :sum, 100.0],
            [:grid_import_power, :sum, 10.0],
          ],
        )
        create_summary(
          date: Date.new(2023, 2, 10),
          values: [
            [:grid_export_power, :sum, 50.0],
            [:grid_import_power, :sum, 20.0],
          ],
        )
      end

      it 'returns grid power data with separate costs, revenue and balance values' do
        expect(call).to be_a(Hash)
        expect(call).to have_key(1)
        expect(call).to have_key(2)

        # Verify structure - actual values depend on seeded prices
        jan_data = call[1][15]
        expect(jan_data).to have_key(:grid_revenue)
        expect(jan_data).to have_key(:grid_costs)
        expect(jan_data).to have_key(:grid_balance)
        expect(jan_data[:grid_balance]).to eq(
          jan_data[:grid_revenue] - jan_data[:grid_costs],
        )

        feb_data = call[2][10]
        expect(feb_data).to have_key(:grid_revenue)
        expect(feb_data).to have_key(:grid_costs)
        expect(feb_data).to have_key(:grid_balance)
        expect(feb_data[:grid_balance]).to eq(
          feb_data[:grid_revenue] - feb_data[:grid_costs],
        )
      end
    end

    context 'when timeframe is not year' do
      let(:sensor) { Sensor::Registry[:inverter_power] }
      let(:timeframe) { Timeframe.all }

      it { is_expected.to be_nil }
    end

    context 'when sensor is blank' do
      let(:sensor) { nil }

      it { is_expected.to be_empty }
    end
  end
end
