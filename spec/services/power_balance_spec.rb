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

  describe '#imbalance' do
    subject(:imbalance) { power_balance.imbalance }

    it 'returns zero when sources and sinks match' do
      expect(imbalance).to eq(0.0)
    end

    context 'when a consumer stays unrecorded' do
      let(:raw_data) { super().merge(house_power: 300) }

      it 'returns what the sources deliver beyond the sinks' do
        expect(imbalance).to eq(200.0)
      end
    end

    context 'when a core sensor has no value' do
      let(:raw_data) { super().merge(grid_export_power: nil) }

      it 'returns nil' do
        expect(imbalance).to be_nil
      end
    end

    context 'when the battery does not report its charging' do
      let(:raw_data) { super().merge(battery_charging_power: nil) }

      it 'returns nil' do
        expect(imbalance).to be_nil
      end
    end

    context 'when the installation has no battery at all' do
      let(:raw_data) do
        super().merge(
          battery_charging_power: nil,
          battery_discharging_power: nil,
        )
      end

      before do
        allow(Sensor::Config).to receive(:configured?).and_call_original
        %i[
          battery_soc
          battery_charging_power
          battery_discharging_power
        ].each do |name|
          allow(Sensor::Config).to receive(:configured?).with(name).and_return(
            false,
          )
        end
      end

      it 'compares the remaining sides' do
        # (1000 + 900) - (150 + 500 + 1300 + 50)
        expect(imbalance).to eq(-100.0)
      end
    end

    context 'when a sensor of one side was not queried' do
      let(:raw_data) { super().except(:battery_charging_power) }

      it 'returns nil' do
        expect(imbalance).to be_nil
      end
    end
  end

  describe '#imbalance_percent' do
    subject(:imbalance_percent) { power_balance.imbalance_percent }

    context 'when a consumer stays unrecorded' do
      let(:raw_data) { super().merge(house_power: 300) }

      it 'returns the share of the incoming energy' do
        expect(imbalance_percent).to be_within(0.01).of(9.09) # 200 / 2200 * 100
      end
    end

    context 'when nothing came in' do
      let(:raw_data) do
        super().merge(
          grid_import_power: 0,
          battery_discharging_power: 0,
          inverter_power: 0,
        )
      end

      it 'returns nil' do
        expect(imbalance_percent).to be_nil
      end
    end
  end

  describe '#imbalance_relevant?' do
    subject(:imbalance_relevant?) { power_balance.imbalance_relevant? }

    it 'is false when sources and sinks match' do
      expect(imbalance_relevant?).to be false
    end

    # The incoming energy is 2200 W, so one percent of it is 22 W

    context 'when the sources exceed the sinks by twelve percent' do
      let(:raw_data) { super().merge(house_power: 236) }

      it 'is true' do
        expect(imbalance_relevant?).to be true
      end
    end

    context 'when the sources exceed the sinks by three percent' do
      let(:raw_data) { super().merge(house_power: 434) }

      it 'is false' do
        expect(imbalance_relevant?).to be false
      end
    end

    context 'when the sinks exceed the sources by three percent' do
      let(:raw_data) { super().merge(house_power: 566) }

      it 'is false' do
        expect(imbalance_relevant?).to be false
      end
    end

    context 'when the sinks exceed the sources by twelve percent' do
      let(:raw_data) { super().merge(house_power: 764) }

      it 'is true' do
        expect(imbalance_relevant?).to be true
      end
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

  describe '#grid_export_limit_active?' do
    subject(:active?) { power_balance.grid_export_limit_active? }

    context 'when grid_export_limit is 100' do
      let(:raw_data) { super().merge(grid_export_limit: 100) }

      it { is_expected.to be(false) }
    end

    context 'when grid_export_limit is 70' do
      let(:raw_data) { super().merge(grid_export_limit: 70) }

      it { is_expected.to be(true) }
    end

    context 'when grid_export_limit is 0' do
      let(:raw_data) { super().merge(grid_export_limit: 0) }

      it { is_expected.to be(true) }
    end

    context 'when grid_export_limit is missing' do
      it { is_expected.to be(false) }
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

  describe '#battery_discharging_power_grid_ratio' do
    subject(:ratio) { power_balance.battery_discharging_power_grid_ratio }

    context 'when part of the discharge came from the grid' do
      let(:raw_data) do
        {
          battery_discharging_power: 6610,
          battery_discharging_power_grid: 3279,
        }
      end

      it { is_expected.to eq(50) }
    end

    # An older Power Splitter reports no such share
    context 'without the grid sensor' do
      let(:raw_data) { { battery_discharging_power: 6610 } }

      it { is_expected.to be_nil }
    end
  end
end
