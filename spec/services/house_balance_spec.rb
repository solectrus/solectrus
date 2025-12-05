describe HouseBalance do
  subject(:house_balance) { described_class.new(sensor_data) }

  let(:sensor_data) { Sensor::Data::Single.new(raw_data, timeframe:) }
  let(:raw_data) { {} }
  let(:timeframe) { Timeframe.now }

  describe '#house_power_without_custom_grid_ratio' do
    subject(:ratio) { house_balance.house_power_without_custom_grid_ratio }

    context 'when ratio exceeds 100%' do
      let(:raw_data) do
        {
          house_power: 200.0,
          house_power_grid: 180.0,
          house_power_without_custom: 50.0,
          custom_power_01: 150.0,
          custom_power_01_grid: 50.0,
        }
      end

      it 'clamps to 100' do
        # house_power_without_custom_grid = 180 - 50 = 130
        # ratio = 130 / 50 * 100 = 260% -> clamped to 100
        expect(ratio).to eq(100)
      end
    end

    context 'when ratio is negative' do
      let(:raw_data) do
        {
          house_power: 200.0,
          house_power_grid: 30.0,
          house_power_without_custom: 100.0,
          custom_power_01: 100.0,
          custom_power_01_grid: 50.0,
        }
      end

      it 'clamps to 0' do
        # house_power_without_custom_grid = 30 - 50 = -20
        # ratio = -20 / 100 * 100 = -20% -> clamped to 0
        expect(ratio).to eq(0)
      end
    end
  end

  describe '#house_without_custom_costs_grid and #house_without_custom_costs_pv' do
    context 'when values are present' do
      let(:raw_data) do
        {
          house_power: 1000.0,
          house_power_without_custom: 400.0,
          house_costs_grid: 2.50,
          house_costs_pv: 1.00,
        }
      end

      it 'calculates grid costs proportionally' do
        # 400.0 / 1000.0 = 0.4, then 0.4 * 2.50 = 1.00
        expect(house_balance.house_without_custom_costs_grid).to be_within(
          0.001,
        ).of(1.00)
      end

      it 'calculates pv costs proportionally' do
        # 400.0 / 1000.0 = 0.4, then 0.4 * 1.00 = 0.40
        expect(house_balance.house_without_custom_costs_pv).to be_within(
          0.001,
        ).of(0.40)
      end
    end

    context 'when house_power is zero' do
      let(:raw_data) do
        {
          house_power: 0,
          house_power_without_custom: 0,
          house_costs_grid: 2.50,
          house_costs_pv: 1.00,
        }
      end

      it 'returns nil for grid costs' do
        expect(house_balance.house_without_custom_costs_grid).to be_nil
      end

      it 'returns nil for pv costs' do
        expect(house_balance.house_without_custom_costs_pv).to be_nil
      end
    end

    context 'with all costs present' do
      let(:raw_data) do
        {
          house_power: 1500.0,
          house_power_without_custom: 600.0,
          house_costs_grid: 3.75,
          house_costs_pv: 1.25,
          house_costs: 5.00,
        }
      end

      it 'grid + pv costs equal house_without_custom_costs (consistency check)' do
        # ratio = 600.0 / 1500.0 = 0.4
        # house_without_custom_costs = 0.4 * 5.00 = 2.00
        # house_without_custom_costs_grid = 0.4 * 3.75 = 1.50
        # house_without_custom_costs_pv = 0.4 * 1.25 = 0.50
        # Sum: 1.50 + 0.50 = 2.00
        expected_total =
          (
            house_balance.house_power_without_custom / house_balance.house_power
          ) * house_balance.house_costs

        actual_sum =
          house_balance.house_without_custom_costs_grid +
            house_balance.house_without_custom_costs_pv

        expect(actual_sum).to be_within(0.001).of(expected_total)
      end
    end
  end
end
