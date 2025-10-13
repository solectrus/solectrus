describe Insights::HeatmapAllTime do
  subject(:service) { described_class.new(sensor:, timeframe:) }

  let(:timeframe) { Timeframe.all }

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
          date: Date.new(2023, 2, 15),
          values: [[:inverter_power_1, :sum, 1200.0]],
        )
        create_summary(
          date: Date.new(2023, 2, 16),
          values: [[:inverter_power_1, :sum, 1500.0]],
        )
      end

      it 'returns a heatmap structure' do
        expect(call).to be_a(Hash)
        expect(call).to have_key(2023)
        expect(call[2023]).to be_a(Hash)
        expect(call[2023][1]).to eq(1000)
        expect(call[2023][2]).to eq(2700)
      end

      it 'groups data by year and month correctly' do
        expect(call[2023]).to include(1 => 1000, 2 => 2700)
      end
    end

    context 'with house_power sensor' do
      let(:sensor) { Sensor::Registry[:house_power] }

      before do
        # Create real SummaryValue records
        create_summary(
          date: Date.new(2023, 1, 15),
          values: [[:house_power, :sum, 2000]],
        )
        create_summary(
          date: Date.new(2023, 2, 15),
          values: [[:house_power, :sum, 2200]],
        )
      end

      it 'returns house power data' do
        expect(call[2023]).to include(1 => 2000, 2 => 2200)
      end
    end

    context 'with grid_power sensor' do
      let(:sensor) { Sensor::Registry[:grid_power] }

      before do
        # Create grid power data
        create_summary(
          date: Date.new(2023, 1, 15),
          values: [
            [:grid_export_power, :sum, 100.0],
            [:grid_import_power, :sum, 10.0],
          ],
        )
        create_summary(
          date: Date.new(2023, 1, 20),
          values: [
            [:grid_export_power, :sum, 125.0],
            [:grid_import_power, :sum, 15.0],
          ],
        )
        create_summary(
          date: Date.new(2023, 2, 10),
          values: [
            [:grid_export_power, :sum, 75.0],
            [:grid_import_power, :sum, 5.0],
          ],
        )
      end

      it 'returns grid power data with separate costs, revenue and balance values' do
        expect(call).to be_a(Hash)
        expect(call).to have_key(2023)

        # Verify structure - actual values depend on seeded prices
        jan_data = call[2023][1]
        expect(jan_data).to have_key(:grid_revenue)
        expect(jan_data).to have_key(:grid_costs)
        expect(jan_data).to have_key(:grid_balance)
        expect(jan_data[:grid_balance]).to eq(
          jan_data[:grid_revenue] - jan_data[:grid_costs],
        )

        feb_data = call[2023][2]
        expect(feb_data).to have_key(:grid_revenue)
        expect(feb_data).to have_key(:grid_costs)
        expect(feb_data).to have_key(:grid_balance)
        expect(feb_data[:grid_balance]).to eq(
          feb_data[:grid_revenue] - feb_data[:grid_costs],
        )
      end
    end

    context 'when timeframe is not all' do
      let(:sensor) { Sensor::Registry[:inverter_power] }
      let(:timeframe) { Timeframe.day }

      it { is_expected.to be_nil }
    end

    context 'when sensor is blank' do
      let(:sensor) { nil }

      it { is_expected.to be_empty }
    end
  end
end
