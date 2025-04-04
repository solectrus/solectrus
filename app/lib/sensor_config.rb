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

  CUSTOM_SENSOR_COUNT = 20
  public_constant :CUSTOM_SENSOR_COUNT

  # Custom defined power sensors
  CUSTOM_SENSORS =
    (1..CUSTOM_SENSOR_COUNT)
      .map { |index| format('custom_power_%02d', index).to_sym }
      .freeze
  public_constant :CUSTOM_SENSORS

  # Sensors that represent power values (in Watts)
  POWER_SENSORS =
    (
      %i[
        inverter_power
        balcony_inverter_power
        house_power
        heatpump_power
        grid_import_power
        grid_export_power
        battery_charging_power
        battery_discharging_power
        wallbox_power
      ] + CUSTOM_SENSORS
    ).freeze
  public_constant :POWER_SENSORS

  POWER_SPLITTER_SENSORS =
    (
      %i[
        house_power_grid
        wallbox_power_grid
        heatpump_power_grid
        battery_charging_power_grid
      ] + CUSTOM_SENSORS.map { :"#{it}_grid" }
    ).freeze
  public_constant :POWER_SPLITTER_SENSORS

  OTHER_SENSORS = %i[
    inverter_power_forecast
    grid_export_limit
    battery_soc
    car_battery_soc
    wallbox_car_connected
    case_temp
    system_status
    system_status_ok
  ].freeze
  public_constant :OTHER_SENSORS

  # Full list of all sensors
  SENSOR_NAMES = (POWER_SENSORS + POWER_SPLITTER_SENSORS + OTHER_SENSORS).freeze
  public_constant :SENSOR_NAMES

  # List of sensors that can be displayed in the top 10 list
  TOP10_SENSORS = POWER_SENSORS
  public_constant :TOP10_SENSORS

  # List of sensors that are calculated (meaning they are built from other sensors)
  CALCULATED_SENSORS = %i[
    autarky
    self_consumption
    savings
    co2_reduction
    house_power_without_custom
  ].freeze
  public_constant :CALCULATED_SENSORS

  # Sensors that can be displayed in the chart
  CHART_SENSORS =
    (
      %i[
        inverter_power
        balcony_inverter_power
        house_power
        house_power_without_custom
        heatpump_power
        grid_power
        battery_power
        battery_soc
        car_battery_soc
        wallbox_power
        case_temp
        autarky
        self_consumption
        savings
        co2_reduction
      ] + CUSTOM_SENSORS
    ).freeze
  public_constant :CHART_SENSORS
  # TODO: Implement savings, which is currently a redirect to inverter_power

  SENSORS_WITH_POWER_SPLITTER = [
    :wallbox_power,
    :heatpump_power,
    :house_power,
    :battery_charging_power,
    *CUSTOM_SENSORS,
  ].freeze
  private_constant :SENSORS_WITH_POWER_SPLITTER

  def initialize(env)
    Rails.logger.info 'Sensor initialization started'

    @sensor_logs = []
    @env = env

    env_hash = env.to_h
    SENSORS_WITH_POWER_SPLITTER.each do |sensor_name|
      env_name = var_for(sensor_name)
      next if env_hash[env_name].blank?

      env_hash[
        "INFLUX_SENSOR_#{sensor_name.upcase}_GRID"
      ] = "power_splitter:#{sensor_name}_grid"
    end

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

    define_excluded_sensor_names(
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

  def exists?(sensor_name, check_policy: true) # rubocop:disable Metrics/CyclomaticComplexity
    case sensor_name
    when :grid_power
      exists_any? :grid_import_power, :grid_export_power
    when :battery_power
      exists_any? :battery_charging_power, :battery_discharging_power
    when :autarky
      exists_all? :house_power, :grid_import_power
    when :self_consumption
      exists_all? :inverter_power, :grid_export_power
    when :savings
      exists_all? :inverter_power, :house_power, :grid_power
    when :house_power_without_custom
      exists? :house_power
    when :co2_reduction
      exists? :inverter_power
    when :car_battery_soc, :wallbox_car_connected
      sensor_defined?(sensor_name) && (!check_policy || ApplicationPolicy.car?)
    when *POWER_SPLITTER_SENSORS
      sensor_defined?(sensor_name) &&
        (!check_policy || ApplicationPolicy.power_splitter?)
    when *SENSOR_NAMES
      sensor_defined?(sensor_name)
    else
      raise ArgumentError,
            "Unknown or invalid sensor name: #{sensor_name.inspect}"
    end
  end

  def sensor_defined?(sensor_name)
    measurement(sensor_name).present? && field(sensor_name).present?
  end

  def exists_any?(*sensor_names)
    sensor_names.any? { |sensor_name| exists?(sensor_name) }
  end

  def exists_all?(*sensor_names)
    sensor_names.all? { |sensor_name| exists?(sensor_name) }
  end

  def display_name(sensor_name)
    Setting.sensor_names[sensor_name].presence ||
      if sensor_name.match?(/\Acustom_power_\d{2}\z/)
        sensor_name.to_s
      elsif sensor_name.end_with?('_grid')
        I18n.t('splitter.grid')
      elsif sensor_name.end_with?('_pv')
        I18n.t('splitter.pv')
      else
        I18n.t("sensors.#{sensor_name}").html_safe
      end
  end

  def editable_sensor_names
    (
      %i[
        inverter_power
        balcony_inverter_power
        house_power
        wallbox_power
        heatpump_power
      ] + CUSTOM_SENSORS
    ).select { exists?(it) }
  end

  def existing_custom_sensor_count
    @existing_custom_sensor_count ||=
      CUSTOM_SENSORS.count { |sensor_name| exists?(sensor_name) }
  end

  # Custom sensors that are EXCLUDED from house power
  def excluded_custom_sensor_names
    existing_custom_sensor_names.select do |sensor_name|
      excluded_sensor_names.include?(sensor_name)
    end
  end

  # Custom sensors that are INCLUDED in house power
  def included_custom_sensor_names
    existing_custom_sensor_names - excluded_custom_sensor_names
  end

  # Custom sensors that are defined
  def existing_custom_sensor_names
    CUSTOM_SENSORS.select { |sensor_name| exists?(sensor_name) }
  end

  # Check the special case in which the entire grid_import_power is only used for house_power
  def single_consumer?
    SensorConfig.x.exists?(:grid_import_power) &&
      !SensorConfig.x.exists?(:wallbox_power) &&
      !SensorConfig.x.exists?(:heatpump_power) &&
      SensorConfig.x.excluded_sensor_names.empty?
  end

  private

  def define_sensor(sensor_name, value)
    if value
      @sensor_logs << format(
        '  - Sensor %<sensor_name>-30s → %<value>s',
        sensor_name:,
        value:,
      )
    end

    define(sensor_name, value)
  end

  def define_excluded_sensor_names(value)
    unless value
      @sensor_logs << '  - Sensor HOUSE_POWER remains unchanged'
      define(:excluded_sensor_names, [])
      return
    end

    sensors_to_exclude = value.split(',').map { it.strip.downcase.to_sym }

    if sensors_to_exclude.any? { |sensor| SENSOR_NAMES.exclude?(sensor) }
      raise Error,
            "Invalid sensor name in INFLUX_EXCLUDE_FROM_HOUSE_POWER: #{value}"
    end

    @sensor_logs << "  - Sensor HOUSE_POWER subtracts #{sensors_to_exclude.map(&:upcase).join(', ')}"
    define(:excluded_sensor_names, sensors_to_exclude)
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
    return unless sensor_name

    public_send(sensor_name.downcase)&.split(':')
  end
end
