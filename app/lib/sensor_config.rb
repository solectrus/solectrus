class SensorConfig # rubocop:disable Metrics/ClassLength
  # Allow global access to the sensor configuration via Rails.application.config
  def self.setup(env)
    Rails.application.config.sensors = SensorConfig.new(env)
  end

  def self.x
    Rails.application.config.sensors
  end

  class Error < RuntimeError
  end

  SENSOR_NAMES = %i[
    inverter_power
    inverter_power_forecast
    house_power
    heatpump_power
    grid_import_power
    grid_export_power
    grid_export_limit
    battery_charging_power
    battery_discharging_power
    battery_soc
    wallbox_power
    case_temp
    system_status
    system_status_ok
    house_power_grid
    wallbox_power_grid
    heatpump_power_grid
  ].freeze
  public_constant :SENSOR_NAMES

  POWER_SENSORS = %i[
    inverter_power
    house_power
    heatpump_power
    grid_import_power
    grid_export_power
    battery_charging_power
    battery_discharging_power
    wallbox_power
  ].freeze
  public_constant :POWER_SENSORS

  CALCULATED_SENSORS = %i[autarky consumption savings co2_reduction].freeze
  public_constant :CALCULATED_SENSORS

  # Combine charging/discharging and import/export fields
  # - `grid_power` instead of `grid_import_power` and `grid_export_power`
  # - `battery_power` instead of `battery_charging_power` and `battery_discharging_power`
  COMBINED_SENSORS =
    (
      SENSOR_NAMES.map do |sensor_name|
        sensor_name
          .to_s
          .gsub(/_import|_export|_discharging|_charging/, '')
          .to_sym
      end + CALCULATED_SENSORS
    ).uniq.freeze
  public_constant :COMBINED_SENSORS

  POWER_SPLITTER_SENSOR_CONFIG = {
    'INFLUX_SENSOR_WALLBOX_POWER_GRID' => 'power_splitter:wallbox_power_grid',
    'INFLUX_SENSOR_HEATPUMP_POWER_GRID' => 'power_splitter:heatpump_power_grid',
    'INFLUX_SENSOR_HOUSE_POWER_GRID' => 'power_splitter:house_power_grid',
  }.freeze
  private_constant :POWER_SPLITTER_SENSOR_CONFIG

  def initialize(env)
    Rails.logger.info 'Sensor initialization started'

    @sensor_logs = []

    env_hash = env.to_h
    env_hash.reverse_merge!(POWER_SPLITTER_SENSOR_CONFIG)

    SENSOR_NAMES.each do |sensor_name|
      var_sensor = var_for(sensor_name)
      value =
        env_hash
          .fetch(var_sensor) do
            build_from_deprecated_config(sensor_name, env_hash)
          end
          .presence

      validate!(sensor_name, value)
      define_sensor(sensor_name, value)
    end

    define_exclude_from_house_power(
      env_hash.fetch('INFLUX_EXCLUDE_FROM_HOUSE_POWER', nil).presence,
    )

    @sensor_logs.each { |log| Rails.logger.info(log) }
    Rails.logger.info 'Sensor initialization completed'
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

  def exists?(sensor_name) # rubocop:disable Metrics/CyclomaticComplexity
    case sensor_name
    when :grid_power
      exists_any? :grid_import_power, :grid_export_power
    when :battery_power
      exists_any? :battery_charging_power, :battery_discharging_power
    when :autarky
      exists_all? :house_power, :grid_import_power
    when :consumption
      exists_all? :inverter_power, :grid_export_power
    when :savings
      exists_all? :inverter_power, :house_power, :grid_power
    when :co2_reduction
      exists? :inverter_power
    when :house_power_grid, :wallbox_power_grid, :heatpump_power_grid
      ApplicationPolicy.power_splitter? && measurement(sensor_name).present? &&
        field(sensor_name).present?
    when *SENSOR_NAMES
      measurement(sensor_name).present? && field(sensor_name).present?
    else
      raise ArgumentError,
            "Unknown or invalid sensor name: #{sensor_name.inspect}"
    end
  end

  def exists_any?(*sensor_names)
    sensor_names.any? { |sensor_name| exists?(sensor_name) }
  end

  def exists_all?(*sensor_names)
    sensor_names.all? { |sensor_name| exists?(sensor_name) }
  end

  private

  def define_sensor(sensor_name, value)
    @sensor_logs << "  - Sensor '#{sensor_name}' #{value ? "mapped to '#{value}'" : 'ignored'}"

    define(sensor_name, value)
  end

  def define_exclude_from_house_power(value)
    unless value
      @sensor_logs << "  - Sensor 'house_power' remains unchanged"
      define(:exclude_from_house_power, [])
      return
    end

    sensors_to_exclude =
      value.split(',').map { |sensor| sensor.strip.downcase.to_sym }

    if sensors_to_exclude.any? { |sensor| SENSOR_NAMES.exclude?(sensor) }
      raise Error,
            "Invalid sensor name in INFLUX_EXCLUDE_FROM_HOUSE_POWER: #{value}"
    end

    @sensor_logs << "  - Sensor 'house_power' excluded #{sensors_to_exclude.join(', ')}"
    define(:exclude_from_house_power, sensors_to_exclude)
  end

  def var_for(sensor_name)
    "INFLUX_SENSOR_#{sensor_name.upcase}"
  end

  def define(sensor_name, value)
    self.class.attr_accessor(sensor_name)
    instance_variable_set(:"@#{sensor_name}", value)
  end

  # Format is "measurement:field"
  SENSOR_REGEX = /\A\S+:\S+\z/
  private_constant :SENSOR_REGEX

  def validate!(sensor_name, value)
    return if value.nil? || value.match?(SENSOR_REGEX)

    raise Error,
          "Sensor '#{sensor_name}' must be in format 'measurement:field'. Got this instead: '#{value}'"
  end

  # Sensors didn't exist in v0.14.5 and earlier, so we need to provide a fallback
  # based on the old environment variables INFLUX_MEASUREMENT_PV and INFLUX_MEASUREMENT_FORECAST
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

  # In v0.14.5 and earlier, the measurements had default values
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
    Rails.logger.warn "  DEPRECATION WARNING: Missing environment variable #{missing_var}.\n" \
                        "  To remove this warning, add the following to your environment:\n" \
                        "    #{missing_var}=#{result}\n" \
                        "  or, when you want to ignore this sensor:\n" \
                        "    #{missing_var}=\n"

    result
  end

  def splitted_sensor_name(sensor_name)
    public_send(sensor_name.downcase)&.split(':')
  end
end
