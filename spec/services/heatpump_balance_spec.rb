describe HeatpumpBalance do
  subject(:heatpump_balance) { described_class.new(sensor_data) }

  let(:sensor_data) { Sensor::Data::Single.new(raw_data, timeframe:) }
  let(:timeframe) { Timeframe.now }

  describe '#heatpump_power_grid_ratio' do
    subject(:heatpump_power_grid_ratio) { heatpump_balance.heatpump_power_grid_ratio }

    context 'when heatpump power and grid power are present' do
      let(:raw_data) { { heatpump_power: 2500, heatpump_power_grid: 600 } }

      it 'returns rounded grid share percentage based on power' do
        expect(heatpump_power_grid_ratio).to eq(24)
      end
    end

    context 'when grid power exceeds total power' do
      let(:raw_data) { { heatpump_power: 100, heatpump_power_grid: 140 } }

      it 'clamps the ratio to 100' do
        expect(heatpump_power_grid_ratio).to eq(100)
      end
    end

    context 'when grid power is negative' do
      let(:raw_data) { { heatpump_power: 100, heatpump_power_grid: -20 } }

      it 'clamps the ratio to 0' do
        expect(heatpump_power_grid_ratio).to eq(0)
      end
    end

    context 'when total heatpump power is zero' do
      let(:raw_data) { { heatpump_power: 0, heatpump_power_grid: 10 } }

      it 'returns nil' do
        expect(heatpump_power_grid_ratio).to be_nil
      end
    end
  end
end
