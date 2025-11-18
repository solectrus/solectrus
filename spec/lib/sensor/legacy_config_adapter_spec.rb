describe Sensor::LegacyConfigAdapter do
  subject(:adapted) { adapter.adapt }

  let(:adapter) { described_class.new(env) }

  describe '#adapt' do
    context 'with standard SENEC configuration' do
      let(:env) do
        {
          'INFLUX_MEASUREMENT_PV' => 'SENEC',
          'INFLUX_MEASUREMENT_FORECAST' => 'Forecast',
        }
      end

      it 'transforms all PV sensors to new format' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to eq(
          'SENEC:inverter_power',
        )
        expect(adapted['INFLUX_SENSOR_HOUSE_POWER']).to eq('SENEC:house_power')
        expect(adapted['INFLUX_SENSOR_GRID_IMPORT_POWER']).to eq(
          'SENEC:grid_power_plus',
        )
        expect(adapted['INFLUX_SENSOR_GRID_EXPORT_POWER']).to eq(
          'SENEC:grid_power_minus',
        )
        expect(adapted['INFLUX_SENSOR_BATTERY_SOC']).to eq(
          'SENEC:bat_fuel_charge',
        )
        expect(adapted['INFLUX_SENSOR_WALLBOX_POWER']).to eq(
          'SENEC:wallbox_charge_power',
        )
      end

      it 'transforms forecast sensors to new format' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER_FORECAST']).to eq(
          'Forecast:watt',
        )
      end

      it 'deletes original environment variables' do
        expect(adapted['INFLUX_MEASUREMENT_PV']).to be_nil
        expect(adapted['INFLUX_MEASUREMENT_FORECAST']).to be_nil
      end

      it 'logs prominent warning banner with details' do
        allow(Rails.logger).to receive(:info)

        adapted

        expect(Rails.logger).to have_received(:info).with(
          include('⚠️  LEGACY CONFIGURATION'),
        )
        expect(Rails.logger).to have_received(:info).with(
          include('Everything works as expected'),
        )
      end

      it 'logs each sensor conversion with instructions' do
        allow(Rails.logger).to receive(:info)

        adapted

        expect(Rails.logger).to have_received(:info).at_least(:once).with(
          include('INFLUX_SENSOR_INVERTER_POWER=SENEC:inverter_power'),
        )
      end

      it 'logs legacy configuration warning without count' do
        allow(Rails.logger).to receive(:info)

        adapted

        expect(Rails.logger).to have_received(:info).with(
          include('⚠️  LEGACY CONFIGURATION'),
        )
        expect(Rails.logger).not_to have_received(:info).with(
          include('sensor(s)'),
        )
      end
    end

    context 'with custom measurement names' do
      let(:env) do
        {
          'INFLUX_MEASUREMENT_PV' => 'CustomPV',
          'INFLUX_MEASUREMENT_FORECAST' => 'CustomForecast',
        }
      end

      it 'uses custom measurement names while preserving field mappings' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to eq(
          'CustomPV:inverter_power',
        )
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER_FORECAST']).to eq(
          'CustomForecast:watt',
        )
      end
    end

    context 'with empty measurement variables (v0.14.5 defaults)' do
      let(:env) do
        { 'INFLUX_MEASUREMENT_PV' => '', 'INFLUX_MEASUREMENT_FORECAST' => '' }
      end

      it 'falls back to SENEC default for PV sensors' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to eq(
          'SENEC:inverter_power',
        )
        expect(adapted['INFLUX_SENSOR_HOUSE_POWER']).to eq('SENEC:house_power')
      end

      it 'falls back to Forecast default for forecast sensors' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER_FORECAST']).to eq(
          'Forecast:watt',
        )
      end
    end

    context 'with only INFLUX_MEASUREMENT_FORECAST set' do
      let(:env) { { 'INFLUX_MEASUREMENT_FORECAST' => 'Forecast' } }

      it 'activates legacy conversion and creates forecast sensor mapping' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER_FORECAST']).to eq(
          'Forecast:watt',
        )
      end

      it 'does not create PV sensor mappings' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to be_nil
        expect(adapted['INFLUX_SENSOR_HOUSE_POWER']).to be_nil
      end

      it 'logs legacy configuration warning' do
        allow(Rails.logger).to receive(:info)

        adapted

        expect(Rails.logger).to have_received(:info).with(
          include('⚠️  LEGACY CONFIGURATION'),
        )
      end
    end

    context 'with blank INFLUX_MEASUREMENT_PV but set INFLUX_MEASUREMENT_FORECAST' do
      let(:env) do
        {
          'INFLUX_MEASUREMENT_PV' => '',
          'INFLUX_MEASUREMENT_FORECAST' => 'Forecast',
        }
      end

      it 'activates legacy conversion for forecast sensors' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER_FORECAST']).to eq(
          'Forecast:watt',
        )
      end

      it 'uses SENEC fallback for blank PV sensor mappings' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to eq(
          'SENEC:inverter_power',
        )
        expect(adapted['INFLUX_SENSOR_HOUSE_POWER']).to eq('SENEC:house_power')
      end
    end

    context 'with complete SENEC sensor set' do
      let(:env) { { 'INFLUX_MEASUREMENT_PV' => 'SENEC' } }

      it 'transforms all 13 mapped legacy sensors' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to eq(
          'SENEC:inverter_power',
        )
        expect(adapted['INFLUX_SENSOR_HOUSE_POWER']).to eq('SENEC:house_power')
        expect(adapted['INFLUX_SENSOR_GRID_IMPORT_POWER']).to eq(
          'SENEC:grid_power_plus',
        )
        expect(adapted['INFLUX_SENSOR_GRID_EXPORT_POWER']).to eq(
          'SENEC:grid_power_minus',
        )
        expect(adapted['INFLUX_SENSOR_GRID_EXPORT_LIMIT']).to eq(
          'SENEC:power_ratio',
        )
        expect(adapted['INFLUX_SENSOR_BATTERY_CHARGING_POWER']).to eq(
          'SENEC:bat_power_plus',
        )
        expect(adapted['INFLUX_SENSOR_BATTERY_DISCHARGING_POWER']).to eq(
          'SENEC:bat_power_minus',
        )
        expect(adapted['INFLUX_SENSOR_BATTERY_SOC']).to eq(
          'SENEC:bat_fuel_charge',
        )
        expect(adapted['INFLUX_SENSOR_WALLBOX_POWER']).to eq(
          'SENEC:wallbox_charge_power',
        )
        expect(adapted['INFLUX_SENSOR_CASE_TEMP']).to eq('SENEC:case_temp')
        expect(adapted['INFLUX_SENSOR_SYSTEM_STATUS']).to eq(
          'SENEC:current_state',
        )
        expect(adapted['INFLUX_SENSOR_SYSTEM_STATUS_OK']).to eq(
          'SENEC:current_state_ok',
        )
      end
    end

    context 'when new INFLUX_SENSOR_* variables exist' do
      let(:env) do
        {
          'INFLUX_MEASUREMENT_PV' => 'SENEC',
          'INFLUX_SENSOR_INVERTER_POWER' => 'NewMeasurement:new_field',
          'INFLUX_SENSOR_HOUSE_POWER' => 'AnotherMeasurement:another_field',
        }
      end

      it 'preserves new format without override' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to eq(
          'NewMeasurement:new_field',
        )
        expect(adapted['INFLUX_SENSOR_HOUSE_POWER']).to eq(
          'AnotherMeasurement:another_field',
        )
      end

      it 'still applies legacy fallback for unmapped sensors' do
        expect(adapted['INFLUX_SENSOR_GRID_IMPORT_POWER']).to eq(
          'SENEC:grid_power_plus',
        )
      end

      it 'does not warn about sensors with new configuration' do
        allow(Rails.logger).to receive(:info)

        adapted

        expect(Rails.logger).not_to have_received(:info).with(
          include('INFLUX_SENSOR_INVERTER_POWER='),
        )
        expect(Rails.logger).not_to have_received(:info).with(
          include('INFLUX_SENSOR_HOUSE_POWER='),
        )
      end

      it 'warns about sensors using legacy configuration' do
        allow(Rails.logger).to receive(:info)

        adapted

        expect(Rails.logger).to have_received(:info).with(
          include('INFLUX_SENSOR_GRID_IMPORT_POWER='),
        )
      end
    end

    context 'with mixed legacy and new configuration' do
      let(:env) do
        {
          'INFLUX_MEASUREMENT_PV' => 'SENEC',
          'INFLUX_SENSOR_INVERTER_POWER' => 'ModernMeasurement:inverter',
        }
      end

      it 'uses new config where present' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to eq(
          'ModernMeasurement:inverter',
        )
      end

      it 'uses legacy fallback for others' do
        expect(adapted['INFLUX_SENSOR_HOUSE_POWER']).to eq('SENEC:house_power')
        expect(adapted['INFLUX_SENSOR_BATTERY_SOC']).to eq(
          'SENEC:bat_fuel_charge',
        )
      end
    end

    context 'without any legacy configuration' do
      let(:env) { {} }

      it 'does not create any sensor mappings' do
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER']).to be_nil
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER_FORECAST']).to be_nil
        expect(adapted['INFLUX_SENSOR_HOUSE_POWER']).to be_nil
      end

      it 'logs that configuration is up-to-date' do
        allow(Rails.logger).to receive(:info)

        adapted

        expect(Rails.logger).to have_received(:info).with(
          include('up-to-date, no legacy conversion required'),
        )
      end
    end

    context 'with unmapped sensor types' do
      let(:env) { { 'INFLUX_MEASUREMENT_PV' => 'SENEC' } }

      it 'does not create mappings for sensors not in FALLBACK_SENSORS' do
        # Custom sensors are not in FALLBACK_SENSORS
        expect(adapted['INFLUX_SENSOR_CUSTOM_POWER_01']).to be_nil
        expect(adapted['INFLUX_SENSOR_INVERTER_POWER_1']).to be_nil
      end
    end
  end

  describe 'Integration with Sensor::Config' do
    describe 'legacy SENEC configuration' do
      let(:env) do
        {
          'INFLUX_MEASUREMENT_PV' => 'SENEC',
          'INFLUX_MEASUREMENT_FORECAST' => 'Forecast',
        }
      end

      before { Sensor::Config.setup(env) }

      it 'configures measurements correctly' do
        expect(Sensor::Config.measurement(:inverter_power)).to eq('SENEC')
        expect(Sensor::Config.measurement(:house_power)).to eq('SENEC')
        expect(Sensor::Config.measurement(:grid_import_power)).to eq('SENEC')
        expect(Sensor::Config.measurement(:inverter_power_forecast)).to eq(
          'Forecast',
        )
      end

      it 'uses legacy SENEC field names' do
        expect(Sensor::Config.field(:grid_import_power)).to eq(
          'grid_power_plus',
        )
        expect(Sensor::Config.field(:grid_export_power)).to eq(
          'grid_power_minus',
        )
        expect(Sensor::Config.field(:battery_charging_power)).to eq(
          'bat_power_plus',
        )
        expect(Sensor::Config.field(:battery_discharging_power)).to eq(
          'bat_power_minus',
        )
        expect(Sensor::Config.field(:battery_soc)).to eq('bat_fuel_charge')
        expect(Sensor::Config.field(:wallbox_power)).to eq(
          'wallbox_charge_power',
        )
        expect(Sensor::Config.field(:system_status)).to eq('current_state')
        expect(Sensor::Config.field(:system_status_ok)).to eq(
          'current_state_ok',
        )
      end

      it 'reports sensor existence correctly' do
        expect(Sensor::Config.exists?(:inverter_power)).to be true
        expect(Sensor::Config.exists?(:house_power)).to be true
        expect(Sensor::Config.exists?(:wallbox_power)).to be true
        expect(Sensor::Config.exists?(:battery_soc)).to be true
        expect(Sensor::Config.exists?(:heatpump_power)).to be false
      end

      it 'logs legacy configuration warning' do
        allow(Rails.logger).to receive(:info)

        Sensor::Config.setup(env)

        expect(Rails.logger).to have_received(:info).with(
          include('⚠️  LEGACY CONFIGURATION'),
        )
      end
    end

    describe 'custom legacy measurement names' do
      let(:env) do
        {
          'INFLUX_MEASUREMENT_PV' => 'MyCustomMeasurement',
          'INFLUX_MEASUREMENT_FORECAST' => 'MyForecast',
        }
      end

      before { Sensor::Config.setup(env) }

      it 'uses custom measurements with legacy field names' do
        expect(Sensor::Config.measurement(:inverter_power)).to eq(
          'MyCustomMeasurement',
        )
        expect(Sensor::Config.measurement(:inverter_power_forecast)).to eq(
          'MyForecast',
        )
        expect(Sensor::Config.field(:grid_import_power)).to eq(
          'grid_power_plus',
        )
      end
    end
  end
end
