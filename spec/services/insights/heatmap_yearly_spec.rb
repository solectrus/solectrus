describe Insights::HeatmapYearly do
  subject(:service) { described_class.new(sensor:, timeframe:) }

  let(:timeframe) { Timeframe.new('2023') }

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
      let(:sensor) { :grid_power }

      before do
        create_summary(
          date: Date.new(2023, 1, 15),
          values: [[:grid_revenue, :sum, 8.0], [:grid_costs, :sum, 2.0]],
        )
        create_summary(
          date: Date.new(2023, 2, 10),
          values: [[:grid_revenue, :sum, 6.0], [:grid_costs, :sum, 1.5]],
        )
      end

      it 'returns grid power data with separate costs and revenue values' do
        expect(call).to be_a(Hash)
        expect(call).to have_key(1)
        expect(call).to have_key(2)

        expect(call[1][15]).to eq({ grid_revenue: 8, grid_costs: 2 })
        expect(call[2][10]).to eq({ grid_revenue: 6, grid_costs: 1.5 })
      end
    end

    context 'when timeframe is not year' do
      let(:sensor) { :inverter_power }
      let(:timeframe) { Timeframe.all }

      it { is_expected.to be_nil }
    end

    context 'when sensor is blank' do
      let(:sensor) { nil }

      it { is_expected.to be_empty }
    end
  end
end
