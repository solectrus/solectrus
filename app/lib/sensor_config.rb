class SensorConfig
  class Error < RuntimeError
  end

  SENSOR_NAMES = %i[
    inverter_power
    inverter_power_forecast
    house_power
    heatpump_power
    grid_power_import
    grid_power_export
    grid_export_limit
    battery_charging_power
    battery_discharging_power
    battery_soc
    wallbox_power
    case_temp
    system_status
    system_status_ok
  ].freeze
  public_constant :SENSOR_NAMES

  POWER_SENSORS = %i[
    inverter_power
    house_power
    heatpump_power
    grid_power_import
    grid_power_export
    battery_charging_power
    battery_discharging_power
    wallbox_power
  ].freeze
  public_constant :POWER_SENSORS

  CALCULATED_SENSORS = %i[autarky consumption savings co2_savings].freeze
  public_constant :CALCULATED_SENSORS

  # Combine plus/minus and import/export fields
  # - `grid_power` instead of `grid_power_import` and `grid_power_export`
  # - `battery_power` instead of `battery_charging_power` and `battery_discharging_power`
  COMBINED_SENSORS =
    (
      SENSOR_NAMES.map do |field|
        field.to_s.gsub(/_import|_export|_discharging|_charging/, '').to_sym
      end + CALCULATED_SENSORS
    ).uniq.freeze
  public_constant :COMBINED_SENSORS

  def initialize(env)
    SENSOR_NAMES.each do |sensor_name|
      var_sensor = var_for(sensor_name)
      value =
        env.fetch(var_sensor) { build_from_deprecated_config(sensor_name, env) }

      validate!(sensor_name, value)
      define(sensor_name, value)
    end
  end

  def measurement(sensor_name)
    @measurement ||= {}
    @measurement[sensor_name] ||= splitted_sensor_name(sensor_name)&.first
  end

  def field(sensor_name)
    @field ||= {}
    @field[sensor_name] ||= splitted_sensor_name(sensor_name)&.last
  end

  def find_by(measurement, field)
    @sensor ||= {}
    @sensor[[measurement, field]] ||= SENSOR_NAMES.find do |sensor_name|
      self.measurement(sensor_name) == measurement &&
        self.field(sensor_name) == field
    end
  end

  private

  def var_for(sensor_name)
    "INFLUX_SENSOR_#{sensor_name.upcase}"
  end

  def define(sensor_name, value)
    self.class.public_send(:attr_accessor, sensor_name)
    instance_variable_set(:"@#{sensor_name}", value)
  end

  # Format is "measurement:field"
  SENSOR_REGEX = /\A\S+:\S+\z/
  private_constant :SENSOR_REGEX

  def validate!(sensor_name, value)
    return if value.nil?
    return if value.match?(SENSOR_REGEX)

    raise Error,
          "Sensor '#{sensor_name}' must be in format 'measurement:field'. Got this instead: '#{value}'"
  end

  # Sensors didn't exist in v0.14.2 and earlier, so we need to provide a fallback
  # based on the old environment variables INFLUX_MEASUREMENT_PV and INFLUX_MEASUREMENT_FORECAST
  FALLBACK_SENSORS = {
    inverter_power: %w[INFLUX_MEASUREMENT_PV inverter_power],
    inverter_power_forecast: %w[INFLUX_MEASUREMENT_FORECAST watt],
    house_power: %w[INFLUX_MEASUREMENT_PV house_power],
    grid_power_import: %w[INFLUX_MEASUREMENT_PV grid_power_plus],
    grid_power_export: %w[INFLUX_MEASUREMENT_PV grid_power_minus],
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

  # In v0.14.2 and earlier, the measurements had default values
  FALLBACK_MEASUREMENTS = {
    'INFLUX_MEASUREMENT_PV' => 'SENEC',
    'INFLUX_MEASUREMENT_FORECAST' => 'Forecast',
  }.freeze
  private_constant :FALLBACK_MEASUREMENTS

  def build_from_deprecated_config(sensor_name, env)
    var_measurement, field = FALLBACK_SENSORS[sensor_name]
    return unless var_measurement

    missing_var = var_for(sensor_name)

    measurement =
      env.fetch(var_measurement, FALLBACK_MEASUREMENTS[var_measurement])

    result = [measurement, field].join(':')
    Rails.logger.warn "\nMissing environment var #{missing_var}. " \
                        "To fix this warning, add the following to your environment:\n" \
                        "#{missing_var}=#{result}"

    result
  end

  def splitted_sensor_name(sensor_name)
    public_send(sensor_name.downcase)&.split(':')
  end
end
