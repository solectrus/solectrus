describe SensorConfig do
  let(:sensor_config) { described_class.new(env) }

  context 'with new configuration' do
    let(:env) do
      {
        'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
        'INFLUX_SENSOR_INVERTER_POWER_FORECAST' => 'forecast:watt',
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_SENSOR_HEATPUMP_POWER' => 'heatpump:power',
        'INFLUX_SENSOR_GRID_POWER_IMPORT' => 'pv:grid_power_import',
        'INFLUX_SENSOR_GRID_POWER_EXPORT' => 'pv:grid_power_export',
        'INFLUX_SENSOR_GRID_EXPORT_LIMIT' => 'pv:grid_export_limit',
        'INFLUX_SENSOR_BATTERY_CHARGING_POWER' => 'pv:battery_charging_power',
        'INFLUX_SENSOR_BATTERY_DISCHARGING_POWER' =>
          'pv:battery_discharging_power',
        'INFLUX_SENSOR_BATTERY_SOC' => 'pv:battery_soc',
        'INFLUX_SENSOR_WALLBOX_POWER' => 'pv:wallbox_power',
        'INFLUX_SENSOR_CASE_TEMP' => 'pv:case_temp',
        'INFLUX_SENSOR_SYSTEM_STATUS' => 'pv:system_status',
        'INFLUX_SENSOR_SYSTEM_STATUS_OK' => 'pv:system_status_ok',
      }
    end

    it 'initializes the sensor configuration' do
      expect(sensor_config).to be_a(described_class)
    end

    describe '#measurement' do
      {
        inverter_power: 'pv',
        house_power: 'pv',
        grid_power_import: 'pv',
        grid_power_export: 'pv',
        grid_export_limit: 'pv',
        battery_charging_power: 'pv',
        battery_discharging_power: 'pv',
        battery_soc: 'pv',
        wallbox_power: 'pv',
        case_temp: 'pv',
        system_status: 'pv',
        system_status_ok: 'pv',
        heatpump_power: 'heatpump',
        inverter_power_forecast: 'forecast',
      }.each do |sensor, measurement|
        it "returns #{measurement} for #{sensor}" do
          expect(sensor_config.measurement(sensor)).to eq(measurement)
        end
      end
    end

    describe '#field' do
      {
        inverter_power: 'inverter_power',
        house_power: 'house_power',
        grid_power_import: 'grid_power_import',
        grid_power_export: 'grid_power_export',
        grid_export_limit: 'grid_export_limit',
        battery_charging_power: 'battery_charging_power',
        battery_discharging_power: 'battery_discharging_power',
        battery_soc: 'battery_soc',
        wallbox_power: 'wallbox_power',
        case_temp: 'case_temp',
        system_status: 'system_status',
        system_status_ok: 'system_status_ok',
        heatpump_power: 'power',
        inverter_power_forecast: 'watt',
      }.each do |sensor, field|
        it "returns #{field} for #{sensor}" do
          expect(sensor_config.field(sensor)).to eq(field)
        end
      end
    end

    describe '#find_by' do
      it 'returns the sensor for measurement and field' do
        expect(sensor_config.find_by('forecast', 'watt')).to eq(
          :inverter_power_forecast,
        )
      end
    end
  end

  context 'with deprecated configuration' do
    let(:env) do
      {
        'INFLUX_MEASUREMENT_PV' => 'SENEC',
        'INFLUX_MEASUREMENT_FORECAST' => 'Forecast',
      }
    end

    it 'initializes the sensor configuration' do
      expect(sensor_config).to be_a(described_class)
    end

    describe '#measurement' do
      {
        inverter_power: 'SENEC',
        house_power: 'SENEC',
        grid_power_import: 'SENEC',
        grid_power_export: 'SENEC',
        grid_export_limit: 'SENEC',
        battery_charging_power: 'SENEC',
        battery_discharging_power: 'SENEC',
        battery_soc: 'SENEC',
        wallbox_power: 'SENEC',
        case_temp: 'SENEC',
        system_status: 'SENEC',
        system_status_ok: 'SENEC',
        heatpump_power: nil,
        inverter_power_forecast: 'Forecast',
      }.each do |sensor, measurement|
        it "returns #{measurement || '<nil>'} for #{sensor}" do
          expect(sensor_config.measurement(sensor)).to eq(measurement)
        end
      end
    end

    describe '#field' do
      {
        inverter_power: 'inverter_power',
        house_power: 'house_power',
        grid_power_import: 'grid_power_plus',
        grid_power_export: 'grid_power_minus',
        grid_export_limit: 'power_ratio',
        battery_charging_power: 'bat_power_plus',
        battery_discharging_power: 'bat_power_minus',
        battery_soc: 'bat_fuel_charge',
        wallbox_power: 'wallbox_charge_power',
        case_temp: 'case_temp',
        system_status: 'current_state',
        system_status_ok: 'current_state_ok',
        heatpump_power: nil,
        inverter_power_forecast: 'watt',
      }.each do |sensor, field|
        it "returns #{field || '<nil>'} for #{sensor}" do
          expect(sensor_config.field(sensor)).to eq(field)
        end
      end
    end
  end

  context 'with invalid sensor value' do
    let(:env) { { 'INFLUX_SENSOR_INVERTER_POWER' => 'invalid' } }

    it 'raises an error' do
      expect { sensor_config }.to raise_error(
        SensorConfig::Error,
        "Sensor 'inverter_power' must be in format 'measurement:field'. Got this instead: 'invalid'",
      )
    end
  end
end
