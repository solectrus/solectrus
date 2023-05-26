describe Calculator::Now do
  let(:calculator) { described_class.new }

  describe '#time' do
    around { |example| freeze_time(&example) }

    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 0,
        },
      )
    end

    it 'returns time of measurement' do
      expect(calculator.time).to eq(Time.current)
    end
  end

  context 'when no sun and battery is empty' do
    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 0,
          house_power: 430,
          bat_power_plus: 0,
          bat_power_minus: 0,
          bat_fuel_charge: 0.0,
          wallbox_charge_power: 0,
          grid_power_plus: 430,
          grid_power_minus: 0,
        },
      )
    end

    it 'calculates power flow' do
      expect(calculator.grid_to_house).to eq(430)
      expect(calculator.inverter_to_house).to eq(0)
      expect(calculator.inverter_to_battery).to eq(0)
      expect(calculator.inverter_to_wallbox).to eq(0)
      expect(calculator.grid_to_wallbox).to eq(0)
      expect(calculator.battery_to_house).to eq(0)
      expect(calculator.grid_to_battery).to eq(0)
      expect(calculator.house_to_grid).to eq(0)
    end
  end

  context 'when no sun and battery is full' do
    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 0,
          house_power: 400,
          bat_power_plus: 0,
          bat_power_minus: 400,
          bat_fuel_charge: 100.0,
          wallbox_charge_power: 0,
          grid_power_plus: 0,
          grid_power_minus: 0,
        },
      )
    end

    it 'calculates power flow' do
      expect(calculator.grid_to_house).to eq(0)
      expect(calculator.inverter_to_house).to eq(0)
      expect(calculator.inverter_to_battery).to eq(0)
      expect(calculator.inverter_to_wallbox).to eq(0)
      expect(calculator.grid_to_wallbox).to eq(0)
      expect(calculator.battery_to_house).to eq(400)
      expect(calculator.grid_to_battery).to eq(0)
      expect(calculator.house_to_grid).to eq(0)
    end
  end

  context 'when no sun and battery is empty and wallbox is charging' do
    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 0,
          house_power: 400,
          bat_power_plus: 0,
          bat_power_minus: 0,
          bat_fuel_charge: 0.0,
          wallbox_charge_power: 10_000,
          grid_power_plus: 10_400,
          grid_power_minus: 0,
        },
      )
    end

    it 'calculates power flow' do
      expect(calculator.battery_to_house).to eq(0)
      expect(calculator.grid_to_house).to eq(400)
      expect(calculator.inverter_to_house).to eq(0)
      expect(calculator.inverter_to_battery).to eq(0)
      expect(calculator.inverter_to_wallbox).to eq(0)
      expect(calculator.grid_to_wallbox).to eq(10_000)
      expect(calculator.grid_to_battery).to eq(0)
      expect(calculator.house_to_grid).to eq(0)
    end
  end

  context 'when there is sun (less than used in the house)' do
    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 100,
          house_power: 400,
          bat_power_plus: 0,
          bat_power_minus: 0,
          bat_fuel_charge: 0.0,
          wallbox_charge_power: 0,
          grid_power_plus: 300,
          grid_power_minus: 0,
        },
      )
    end

    it 'calculates power flow' do
      expect(calculator.battery_to_house).to eq(0)
      expect(calculator.grid_to_house).to eq(300)
      expect(calculator.inverter_to_house).to eq(100)
      expect(calculator.inverter_to_battery).to eq(0)
      expect(calculator.inverter_to_wallbox).to eq(0)
      expect(calculator.grid_to_wallbox).to eq(0)
      expect(calculator.grid_to_battery).to eq(0)
      expect(calculator.house_to_grid).to eq(0)
    end
  end

  context 'when there is sun (more than used in the house) and battery is empty' do
    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 500,
          house_power: 400,
          bat_power_plus: 100,
          bat_power_minus: 0,
          bat_fuel_charge: 0.0,
          wallbox_charge_power: 0,
          grid_power_plus: 0,
          grid_power_minus: 0,
        },
      )
    end

    it 'calculates power flow' do
      expect(calculator.battery_to_house).to eq(0)
      expect(calculator.grid_to_house).to eq(0)
      expect(calculator.inverter_to_house).to eq(400)
      expect(calculator.inverter_to_battery).to eq(100)
      expect(calculator.inverter_to_wallbox).to eq(0)
      expect(calculator.grid_to_wallbox).to eq(0)
      expect(calculator.grid_to_battery).to eq(0)
      expect(calculator.house_to_grid).to eq(0)
    end
  end

  context 'when there is sun (more than used in the house) and battery is full' do
    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 500,
          house_power: 400,
          bat_power_plus: 0,
          bat_power_minus: 0,
          bat_fuel_charge: 100.0,
          wallbox_charge_power: 0,
          grid_power_plus: 0,
          grid_power_minus: 100,
        },
      )
    end

    it 'calculates power flow' do
      expect(calculator.battery_to_house).to eq(0)
      expect(calculator.grid_to_house).to eq(0)
      expect(calculator.inverter_to_house).to eq(400)
      expect(calculator.inverter_to_battery).to eq(0)
      expect(calculator.inverter_to_wallbox).to eq(0)
      expect(calculator.grid_to_wallbox).to eq(0)
      expect(calculator.grid_to_battery).to eq(0)
      expect(calculator.house_to_grid).to eq(100)
    end
  end

  context 'when emergency charge' do
    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 300,
          house_power: 400,
          bat_power_plus: 2_500,
          bat_power_minus: 0,
          bat_fuel_charge: 0.0,
          wallbox_charge_power: 0,
          grid_power_plus: 2_900,
          grid_power_minus: 0,
        },
      )
    end

    it 'calculates power flow' do
      expect(calculator.battery_to_house).to eq(0)
      expect(calculator.grid_to_house).to eq(100)
      expect(calculator.inverter_to_house).to eq(300)
      expect(calculator.inverter_to_battery).to eq(0)
      expect(calculator.inverter_to_wallbox).to eq(0)
      expect(calculator.grid_to_wallbox).to eq(0)
      expect(calculator.grid_to_battery).to eq(2_500)
      expect(calculator.house_to_grid).to eq(0)
    end
  end

  context 'when feeding' do
    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 5_000,
          house_power: 400,
          bat_power_plus: 2_500,
          bat_power_minus: 0,
          bat_fuel_charge: 10.0,
          wallbox_charge_power: 0,
          grid_power_plus: 0,
          grid_power_minus: 2_100,
        },
      )
    end

    it 'calculates power flow' do
      expect(calculator.battery_to_house).to eq(0)
      expect(calculator.grid_to_house).to eq(0)
      expect(calculator.inverter_to_house).to eq(400)

      expect(calculator.inverter_to_battery).to eq(2_500)
      expect(calculator.inverter_to_wallbox).to eq(0)
      expect(calculator.grid_to_wallbox).to eq(0)
      expect(calculator.grid_to_battery).to eq(0)
      expect(calculator.house_to_grid).to eq(2_100)
    end
  end
end
