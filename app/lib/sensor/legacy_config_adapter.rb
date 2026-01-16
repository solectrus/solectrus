# Adapter to support legacy SENEC-era environment variable configuration.
# Transforms old INFLUX_MEASUREMENT_* variables into new INFLUX_SENSOR_* format.
#
# This provides backward compatibility for existing installations while
# encouraging migration to the new configuration format through deprecation warnings.
class Sensor::LegacyConfigAdapter
  include Sensor::ConfigLogger

  def initialize(env)
    @env = env
    @warnings = []
  end

  # Transforms legacy INFLUX_MEASUREMENT_* variables to new INFLUX_SENSOR_* format.
  # Returns a new hash where legacy measurement variables are removed and replaced
  # by the corresponding sensor variables.
  def adapt
    adapted_env = env.to_h.dup

    if legacy_mode?(adapted_env)
      # Only iterate over sensors that have legacy fallback mappings
      FALLBACK_SENSORS.each_key do |sensor_name|
        new_env_var = "INFLUX_SENSOR_#{sensor_name.upcase}"
        next if adapted_env[new_env_var].present?

        legacy_value = build_from_deprecated_config(sensor_name)
        adapted_env[new_env_var] = legacy_value if legacy_value.present?
      end

      # Remove legacy measurement variables
      adapted_env.delete('INFLUX_MEASUREMENT_PV')
      adapted_env.delete('INFLUX_MEASUREMENT_FORECAST')
    end

    log_summary

    adapted_env
  end

  private

  attr_reader :env, :warnings

  # Mapping of sensor names to their legacy environment variables
  # Format: sensor_name => [measurement_env_var, field_name]
  FALLBACK_SENSORS = {
    inverter_power: %w[INFLUX_MEASUREMENT_PV inverter_power],
    inverter_power_forecast: %w[INFLUX_MEASUREMENT_FORECAST watt],
    house_power: %w[INFLUX_MEASUREMENT_PV house_power],
    grid_import_power: %w[INFLUX_MEASUREMENT_PV grid_power_plus],
    grid_export_power: %w[INFLUX_MEASUREMENT_PV grid_power_minus],
    grid_export_limit: %w[INFLUX_MEASUREMENT_PV power_ratio],
    battery_charging_power: %w[INFLUX_MEASUREMENT_PV bat_power_plus],
    battery_discharging_power: %w[INFLUX_MEASUREMENT_PV bat_power_minus],
    battery_soc: %w[INFLUX_MEASUREMENT_PV bat_fuel_charge],
    wallbox_power: %w[INFLUX_MEASUREMENT_PV wallbox_charge_power],
    case_temp: %w[INFLUX_MEASUREMENT_PV case_temp],
    system_status: %w[INFLUX_MEASUREMENT_PV current_state],
    system_status_ok: %w[INFLUX_MEASUREMENT_PV current_state_ok],
  }.freeze
  private_constant :FALLBACK_SENSORS

  # Default values for legacy measurement variables (from v0.14.5 and earlier)
  FALLBACK_MEASUREMENTS = {
    'INFLUX_MEASUREMENT_PV' => 'SENEC',
    'INFLUX_MEASUREMENT_FORECAST' => 'Forecast',
  }.freeze
  private_constant :FALLBACK_MEASUREMENTS

  def build_from_deprecated_config(sensor_name)
    measurement_env_var, field = FALLBACK_SENSORS[sensor_name]

    measurement =
      env[measurement_env_var].presence ||
        FALLBACK_MEASUREMENTS[measurement_env_var]
    return if measurement.blank?

    result = "#{measurement}:#{field}"
    warnings << "INFLUX_SENSOR_#{sensor_name.upcase}=#{result}"
    result
  end

  # Legacy mode is active when:
  # 1. Explicit legacy variables are set (INFLUX_MEASUREMENT_PV or INFLUX_MEASUREMENT_FORECAST), OR
  # 2. The primary sensor INFLUX_SENSOR_GRID_IMPORT_POWER is missing
  def legacy_mode?(adapted_env)
    explicit_legacy_config?(adapted_env) || !sensor_config?(adapted_env)
  end

  def explicit_legacy_config?(adapted_env)
    adapted_env.key?('INFLUX_MEASUREMENT_PV') ||
      adapted_env.key?('INFLUX_MEASUREMENT_FORECAST')
  end

  def sensor_config?(adapted_env)
    adapted_env['INFLUX_SENSOR_GRID_IMPORT_POWER'].present?
  end

  def log_summary
    if warnings.empty?
      log_line 'Configuration is up-to-date, no legacy conversion required'
      return
    end

    log_section_header('⚠️  LEGACY CONFIGURATION', char: '·')
    log_line 'Legacy configuration detected and automatically converted.'
    log_line 'Everything works as expected, but please consider updating your configuration:'
    log_blank

    warnings.each { |warning| log_line(warning) }

    log_blank
    log_line 'After updating, you can remove INFLUX_MEASUREMENT_PV and INFLUX_MEASUREMENT_FORECAST.'
  end
end
