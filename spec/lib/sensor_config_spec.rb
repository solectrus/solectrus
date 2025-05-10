describe SensorConfig do
  let(:sensor_config) { described_class.new(env) }

  context 'with new configuration (including heatpump)' do
    let(:env) do
      {
        'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
        'INFLUX_SENSOR_INVERTER_POWER_FORECAST' => 'forecast:watt',
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_SENSOR_HEATPUMP_POWER' => 'heatpump:power',
        'INFLUX_SENSOR_GRID_IMPORT_POWER' => 'pv:grid_import_power',
        'INFLUX_SENSOR_GRID_EXPORT_POWER' => 'pv:grid_export_power',
        'INFLUX_SENSOR_GRID_EXPORT_LIMIT' => 'pv:grid_export_limit',
        'INFLUX_SENSOR_BATTERY_CHARGING_POWER' => 'pv:battery_charging_power',
        'INFLUX_SENSOR_BATTERY_DISCHARGING_POWER' =>
          'pv:battery_discharging_power',
        'INFLUX_SENSOR_BATTERY_SOC' => 'pv:battery_soc',
        'INFLUX_SENSOR_WALLBOX_POWER' => 'pv:wallbox_power',
        'INFLUX_SENSOR_CASE_TEMP' => 'pv:case_temp',
        'INFLUX_SENSOR_SYSTEM_STATUS' => 'pv:system_status',
        'INFLUX_SENSOR_SYSTEM_STATUS_OK' => 'pv:system_status_ok',
        'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'HEATPUMP_POWER',
      }
    end

    it 'initializes the sensor configuration' do
      expect(sensor_config).to be_a(described_class)
    end

    describe '#measurement' do
      {
        inverter_power: 'pv',
        house_power: 'pv',
        grid_import_power: 'pv',
        grid_export_power: 'pv',
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
        grid_import_power: 'grid_import_power',
        grid_export_power: 'grid_export_power',
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

    describe '#excluded_sensor_names' do
      it 'returns heatpump' do
        expect(sensor_config.excluded_sensor_names).to eq([:heatpump_power])
      end
    end

    describe '#exists?' do
      it 'returns true for existing sensor' do
        expect(sensor_config.exists?(:inverter_power)).to be(true)
        expect(sensor_config.exists?(:wallbox_power)).to be(true)
        expect(sensor_config.exists?(:heatpump_power)).to be(true)
      end

      it 'returns true for combined sensors' do
        expect(sensor_config.exists?(:grid_power)).to be(true)
        expect(sensor_config.exists?(:battery_power)).to be(true)
      end

      it 'returns true for calculated sensors' do
        expect(sensor_config.exists?(:autarky)).to be(true)
        expect(sensor_config.exists?(:self_consumption)).to be(true)
        expect(sensor_config.exists?(:savings)).to be(true)
        expect(sensor_config.exists?(:co2_reduction)).to be(true)
      end

      it 'fails for invalid sensor' do
        expect { sensor_config.exists?(:invalid) }.to raise_error(ArgumentError)
      end
    end

    describe '#display_name' do
      context 'without customization' do
        it 'returns the display name for a sensor' do
          expect(sensor_config.display_name(:inverter_power)).to eq(
            'Generation',
          )
        end
      end

      context 'with customization' do
        before do
          Setting.sensor_names = { inverter_power: 'My little PV system' }
        end

        it 'returns the display name for a sensor' do
          expect(sensor_config.display_name(:inverter_power)).to eq(
            'My little PV system',
          )
        end
      end
    end
  end

  context 'with new configuration (including heatpump, but not excluded)' do
    let(:env) do
      {
        'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
        'INFLUX_SENSOR_INVERTER_POWER_FORECAST' => 'forecast:watt',
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_SENSOR_HEATPUMP_POWER' => 'heatpump:power',
        'INFLUX_SENSOR_GRID_IMPORT_POWER' => 'pv:grid_import_power',
        'INFLUX_SENSOR_GRID_EXPORT_POWER' => 'pv:grid_export_power',
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

    describe '#excluded_sensor_names' do
      it 'returns blank array' do
        expect(sensor_config.excluded_sensor_names).to eq([])
      end
    end
  end

  context 'with new configuration (without heatpump)' do
    let(:env) do
      {
        'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
        'INFLUX_SENSOR_INVERTER_POWER_FORECAST' => 'forecast:watt',
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_SENSOR_GRID_IMPORT_POWER' => 'pv:grid_import_power',
        'INFLUX_SENSOR_GRID_EXPORT_POWER' => 'pv:grid_export_power',
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

    describe '#excluded_sensor_names' do
      it 'returns blank array' do
        expect(sensor_config.excluded_sensor_names).to eq([])
      end
    end

    describe '#exists?' do
      it 'returns false for non-existing sensor' do
        expect(sensor_config.exists?(:heatpump_power)).to be(false)
      end
    end
  end

  context 'with some blank sensors' do
    let(:env) do
      {
        'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
        'INFLUX_SENSOR_INVERTER_POWER_FORECAST' => '',
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_SENSOR_GRID_IMPORT_POWER' => 'pv:grid_import_power',
        'INFLUX_SENSOR_GRID_EXPORT_POWER' => 'pv:grid_export_power',
        'INFLUX_SENSOR_GRID_EXPORT_LIMIT' => 'pv:grid_export_limit',
        'INFLUX_SENSOR_BATTERY_CHARGING_POWER' => 'pv:battery_charging_power',
        'INFLUX_SENSOR_BATTERY_DISCHARGING_POWER' =>
          'pv:battery_discharging_power',
        'INFLUX_SENSOR_BATTERY_SOC' => 'pv:battery_soc',
        'INFLUX_SENSOR_WALLBOX_POWER' => '',
        'INFLUX_SENSOR_CASE_TEMP' => '',
        'INFLUX_SENSOR_SYSTEM_STATUS' => '',
        'INFLUX_SENSOR_SYSTEM_STATUS_OK' => '',
      }
    end

    describe '#exists?' do
      it 'returns false for blank sensor' do
        expect(sensor_config.exists?(:inverter_power_forecast)).to be(false)
        expect(sensor_config.exists?(:case_temp)).to be(false)
        expect(sensor_config.exists?(:system_status)).to be(false)
        expect(sensor_config.exists?(:system_status_ok)).to be(false)
      end

      it 'returns true for non-blank sensor' do
        expect(sensor_config.exists?(:inverter_power)).to be(true)
        expect(sensor_config.exists?(:house_power)).to be(true)
        expect(sensor_config.exists?(:grid_import_power)).to be(true)
        expect(sensor_config.exists?(:grid_export_power)).to be(true)
        expect(sensor_config.exists?(:grid_export_limit)).to be(true)
        expect(sensor_config.exists?(:battery_charging_power)).to be(true)
        expect(sensor_config.exists?(:battery_discharging_power)).to be(true)
        expect(sensor_config.exists?(:battery_soc)).to be(true)
      end

      it 'fails for invalid sensor name' do
        # Symbol, but unknown
        expect { sensor_config.exists?(:foo) }.to raise_error(
          ArgumentError,
          'Unknown or invalid sensor name: :foo',
        )

        # String is not supported, only Symbol
        expect { sensor_config.exists?('inverter_power') }.to raise_error(
          ArgumentError,
          'Unknown or invalid sensor name: "inverter_power"',
        )

        # Array is not supported, only single sensor
        expect { sensor_config.exists?([:inverter_power]) }.to raise_error(
          ArgumentError,
          'Unknown or invalid sensor name: [:inverter_power]',
        )
      end
    end

    describe '#exists_all?' do
      it 'returns true when all exists' do
        expect(sensor_config.exists_all?(:battery_soc, :house_power)).to be(
          true,
        )
      end

      it 'returns false when mixed' do
        expect(sensor_config.exists_all?(:battery_soc, :case_temp)).to be(false)
      end

      it 'returns false when all not exists' do
        expect(sensor_config.exists_all?(:case_temp, :system_status)).to be(
          false,
        )
      end
    end

    describe '#exists_any?' do
      it 'returns true when all exists' do
        expect(sensor_config.exists_any?(:battery_soc, :house_power)).to be(
          true,
        )
      end

      it 'returns true when mixed' do
        expect(sensor_config.exists_any?(:battery_soc, :case_temp)).to be(true)
      end

      it 'returns false when all not exists' do
        expect(sensor_config.exists_any?(:case_temp, :system_status)).to be(
          false,
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
        grid_import_power: 'SENEC',
        grid_export_power: 'SENEC',
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
        grid_import_power: 'grid_power_plus',
        grid_export_power: 'grid_power_minus',
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

    describe '#excluded_sensor_names' do
      it 'returns blank array' do
        expect(sensor_config.excluded_sensor_names).to eq([])
      end
    end

    describe '#exists?' do
      it 'returns false for non-existing sensor' do
        expect(sensor_config.exists?(:heatpump_power)).to be(false)
      end
    end
  end

  context 'with invalid sensor value' do
    let(:env) { { 'INFLUX_SENSOR_INVERTER_POWER' => 'invalid' } }

    it 'raises an error' do
      expect { sensor_config }.to raise_error(
        described_class::Error,
        "Sensor 'inverter_power' must be in format 'measurement:field'. Got this instead: 'invalid'",
      )
    end
  end

  context 'with valid INFLUX_EXCLUDE_FROM_HOUSE_POWER' do
    let(:env) do
      {
        'INFLUX_SENSOR_HEATPUMP_POWER' => 'heatpump:power',
        'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'HEATPUMP_POWER',
      }
    end

    it 'initializes the sensor configuration' do
      expect(sensor_config).to be_a(described_class)
    end

    describe '#excluded_sensor_names' do
      it 'returns the given sensor field' do
        expect(sensor_config.excluded_sensor_names).to eq([:heatpump_power])
      end
    end
  end

  context 'with lowercase INFLUX_EXCLUDE_FROM_HOUSE_POWER (still valid)' do
    let(:env) do
      {
        'INFLUX_SENSOR_HEATPUMP_POWER' => 'heatpump:power',
        'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'heatpump_power',
      }
    end

    describe '#excluded_sensor_names' do
      it 'returns the given sensor field' do
        expect(sensor_config.excluded_sensor_names).to eq([:heatpump_power])
      end
    end
  end

  context 'with blank INFLUX_EXCLUDE_FROM_HOUSE_POWER' do
    let(:env) { { 'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => '' } }

    describe '#excluded_sensor_names' do
      it 'returns blank array' do
        expect(sensor_config.excluded_sensor_names).to eq([])
      end
    end
  end

  context 'with invalid INFLUX_EXCLUDE_FROM_HOUSE_POWER' do
    let(:env) do
      {
        'INFLUX_SENSOR_HEATPUMP_POWER' => 'heatpump:power',
        'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'FOO',
      }
    end

    it 'fails at initialization' do
      expect { sensor_config }.to raise_error(
        described_class::Error,
        'Invalid sensor name in INFLUX_EXCLUDE_FROM_HOUSE_POWER: FOO',
      )
    end
  end
end
