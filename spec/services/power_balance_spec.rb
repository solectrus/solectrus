describe PowerBalance do
  subject(:power_balance) { described_class.new(sensor_data) }

  let(:sensor_data) { Sensor::Data::Single.new(raw_data, timeframe:) }
  let(:raw_data) do
    {
      grid_import_power: 1000,
      battery_discharging_power: 300,
      inverter_power: 900,
      inverter_power_1: 800,
      inverter_power_2: 100,
      grid_export_power: 150,
      battery_charging_power: 200,
      house_power: 500,
      wallbox_power: 1300,
      heatpump_power: 50,
    }
  end
  let(:timeframe) { Timeframe.now }

  describe '#total_plus' do
    subject(:total_plus) { power_balance.total_plus }

    it 'calculates sum of grid import, battery discharging, and inverter power' do
      expect(total_plus).to eq(2200.0) # 1000 + 300 + 900
    end

    context 'when values are nil' do
      let(:raw_data) do
        {
          grid_import_power: nil,
          battery_discharging_power: nil,
          inverter_power: nil,
          grid_export_power: 150,
          battery_charging_power: 200,
          house_power: 500,
          wallbox_power: 1300,
          heatpump_power: 50,
        }
      end

      it 'returns 0' do
        expect(total_plus).to eq(0.0)
      end
    end
  end

  describe '#total_minus' do
    subject(:total_minus) { power_balance.total_minus }

    it 'calculates sum of grid export, battery charging, house, wallbox, and heatpump power' do
      expect(total_minus).to eq(2200.0) # 150 + 200 + 500 + 1300 + 50
    end
  end

  describe '#total' do
    subject(:total) { power_balance.total }

    it 'returns the maximum of total_minus and total_plus' do
      expect(total).to eq(2200.0)
    end
  end

  describe '#inverter_power_percent' do
    subject(:inverter_power_percent) { power_balance.inverter_power_percent }

    it 'calculates inverter power as percentage of total_plus' do
      expect(inverter_power_percent).to be_within(0.01).of(40.91) # 900 / 2200 * 100
    end

    context 'when total_plus is zero' do
      let(:raw_data) do
        {
          grid_import_power: 0,
          battery_discharging_power: 0,
          inverter_power: 0,
          grid_export_power: 150,
          battery_charging_power: 200,
          house_power: 500,
          wallbox_power: 1300,
          heatpump_power: 50,
        }
      end

      it 'returns 0' do
        expect(inverter_power_percent).to eq(0)
      end
    end
  end

  describe 'method delegation' do
    it 'responds to methods on the wrapped object' do
      expect(power_balance).to respond_to(:timeframe)
      expect(power_balance).to respond_to(:valid_multi_inverter?)
      expect(power_balance).to respond_to(:house_power)
    end

    it 'does not respond to invalid methods' do
      expect(power_balance).not_to respond_to(:invalid_method)
    end
  end

  describe '#house_power_grid_ratio' do
    subject(:house_power_grid_ratio) { power_balance.house_power_grid_ratio }

    context 'when grid power exceeds total power' do
      let(:raw_data) { { house_power: 100, house_power_grid: 107 } }

      it 'clamps the ratio to 100' do
        expect(house_power_grid_ratio).to eq(100)
      end
    end

    context 'when grid power is negative' do
      let(:raw_data) { { house_power: 100, house_power_grid: -10 } }

      it 'clamps the ratio to 0' do
        expect(house_power_grid_ratio).to eq(0)
      end
    end
  end

  describe '#forecast_deviation' do
    subject(:forecast_deviation) { power_balance.forecast_deviation }

    context 'when actual exceeds forecast' do
      let(:raw_data) { { inverter_power: 11_000, inverter_power_forecast: 10_000 } }

      it 'returns positive deviation in Wh' do
        expect(forecast_deviation).to eq(1000)
      end
    end

    context 'when actual is less than forecast' do
      let(:raw_data) { { inverter_power: 9000, inverter_power_forecast: 10_000 } }

      it 'returns negative deviation in Wh' do
        expect(forecast_deviation).to eq(-1000)
      end
    end

    context 'when forecast is zero and actual is positive' do
      let(:raw_data) { { inverter_power: 900, inverter_power_forecast: 0 } }

      it 'returns the actual value as deviation' do
        expect(forecast_deviation).to eq(900)
      end
    end

    context 'when both forecast and actual are zero' do
      let(:raw_data) { { inverter_power: 0, inverter_power_forecast: 0 } }

      it 'returns zero' do
        expect(forecast_deviation).to eq(0)
      end
    end

    context 'when forecast is not available' do
      let(:raw_data) { { inverter_power: 1000 } }

      it 'returns nil' do
        expect(forecast_deviation).to be_nil
      end
    end
  end
end
