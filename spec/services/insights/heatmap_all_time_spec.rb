describe Insights::HeatmapAllTime do
  subject(:service) { described_class.new(sensor:, timeframe:) }

  let(:timeframe) { Timeframe.all }

  describe '#call' do
    subject(:call) { service.call }

    context 'with valid sensor and timeframe' do
      let(:sensor) { :inverter_power }

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
      let(:sensor) { :house_power }

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
      let(:sensor) { :grid_power }

      before do
        # Create grid costs and revenue data
        create_summary(
          date: Date.new(2023, 1, 15),
          values: [[:grid_revenue, :sum, 8.0], [:grid_costs, :sum, 2.0]],
        )
        create_summary(
          date: Date.new(2023, 1, 20),
          values: [[:grid_revenue, :sum, 10.0], [:grid_costs, :sum, 3.0]],
        )
        create_summary(
          date: Date.new(2023, 2, 10),
          values: [[:grid_revenue, :sum, 6.0], [:grid_costs, :sum, 1.5]],
        )
      end

      it 'returns grid power data with separate costs and revenue values' do
        expect(call).to be_a(Hash)
        expect(call).to have_key(2023)

        # January: 8 + 10 = 18 revenue, 2 + 3 = 5 costs
        expect(call[2023][1]).to eq({ grid_revenue: 18, grid_costs: 5 })

        # February: 6 revenue, 1.5 costs
        expect(call[2023][2]).to eq({ grid_revenue: 6, grid_costs: 1.5 })
      end
    end

    context 'when timeframe is not all' do
      let(:sensor) { :inverter_power }
      let(:timeframe) { Timeframe.day }

      it { is_expected.to be_nil }
    end

    context 'when sensor is blank' do
      let(:sensor) { nil }

      it { is_expected.to be_empty }
    end
  end
end
