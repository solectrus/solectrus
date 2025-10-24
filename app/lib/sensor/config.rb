class Sensor::Config # rubocop:disable Metrics/ClassLength
  include Singleton
  include Sensor::ConfigLogger

  ConfigEntry =
    Data.define(:measurement, :field, :options) do
      def initialize(measurement:, field:, options: {})
        super
      end

      def self.from_env(value)
        measurement, field = value.split(':')

        new(measurement:, field:) if measurement && field
      end
    end
  private_constant :ConfigEntry

  # Class method delegation to singleton instance
  class << self
    extend Forwardable

    def_delegators :instance,
                   :setup,
                   :measurement,
                   :field,
                   :mapping,
                   :configured?,
                   :exists?,
                   :sensors,
                   :house_power_excluded_sensors,
                   :house_power_excluded_custom_sensors,
                   :house_power_included_custom_sensors,
                   :nameable_sensors,
                   :inverter_sensors,
                   :custom_inverter_sensors,
                   :custom_power_sensors,
                   :chart_sensors,
                   :top10_sensors,
                   :multi_inverter?,
                   :clear_cache!
  end

  def self.display_name(sensor_name, format = :short)
    Sensor::Registry[sensor_name].display_name(format)
  end

  def setup(env, validate_summaries: false)
    # Reset all instance variables to avoid caching conflicts
    instance_variables.each { |var| remove_instance_variable(var) }

    @configurations = {}
    @sensor_logs = []
    @sensor_warnings = []
    @house_power_exclusions = nil

    log_section_header('SENSOR INITIALIZATION', blank_after: false)

    # Adapt legacy SENEC-era environment variables to new format
    @env = Sensor::LegacyConfigAdapter.new(env).adapt

    parse_configurations
    auto_configure_power_splitter_sensors

    log_configurations

    # Validate summaries if requested (only needed during application startup)
    if validate_summaries &&
         ActiveRecord::Base.connection.table_exists?(:summaries)
      Sensor::SummaryInvalidator.ensure_valid!
    end

    log_section_footer
  end

  attr_reader :env, :configurations

  def ensure_configurations!
    return :ok if configurations.present?

    # Auto-setup if not already done (e.g., in test environment)
    setup(ENV) if configurations.nil?

    if configurations.blank?
      raise StandardError,
            'Sensor configurations not present, did you forget to call Sensor::Config.setup?'
    end

    :ok
  end

  def measurement(sensor_name)
    configurations[sensor_name]&.measurement
  end

  def field(sensor_name)
    configurations[sensor_name]&.field
  end

  def configured?(sensor_name)
    configurations&.key?(sensor_name)
  end

  def mapping(sensor_name)
    return unless configured?(sensor_name)

    "#{measurement(sensor_name)}:#{field(sensor_name)}"
  end

  def find_by(measurement:, field:)
    configurations
      .find do |_name, config|
        config.measurement == measurement && config.field == field
      end
      &.first
  end

  # Check if a sensor is configured and permitted
  def exists?(sensor_name, check_policy: true)
    # This will raise ArgumentError if sensor doesn't exist in Registry
    sensor = Sensor::Registry[sensor_name]

    if sensor.calculated? || sensor.sql_calculated?
      !check_policy || sensor.permitted?
    else
      ensure_configurations!
      configurations.key?(sensor_name) && (!check_policy || sensor.permitted?)
    end
  end

  def house_power_excluded_sensors
    ensure_configurations!
    house_power_config = configurations[:house_power]
    return [] unless house_power_config

    house_power_config.options[:exclude] || []
  end

  def house_power_excluded_custom_sensors
    @house_power_excluded_custom_sensors ||=
      house_power_excluded_sensors.select do |sensor|
        sensor.is_a?(Sensor::Definitions::CustomPower)
      end
  end

  def house_power_included_custom_sensors
    @house_power_included_custom_sensors ||=
      filter_sensors do |sensor|
        sensor.is_a?(Sensor::Definitions::CustomPower) &&
          house_power_excluded_sensors.exclude?(sensor)
      end
  end

  def single_consumer?
    Sensor::Registry
      .by_category(:consumer)
      .one? { |sensor| exists?(sensor.name) }
  end

  def sensors
    @sensors ||= Sensor::Registry.all.select { |sensor| exists?(sensor.name) }
  end

  def nameable_sensors
    @nameable_sensors ||= sensors.select(&:nameable?)
  end

  ### Inverter

  def inverter_sensors
    @inverter_sensors ||=
      sensors.grep(Sensor::Definitions::InverterPower) + custom_inverter_sensors
  end

  def custom_inverter_sensors
    @custom_inverter_sensors ||=
      sensors.grep(Sensor::Definitions::CustomInverterPower)
  end

  def multi_inverter?
    ApplicationPolicy.multi_inverter? && custom_inverter_sensors.any?
  end

  ###

  def custom_power_sensors
    @custom_power_sensors ||= sensors.grep(Sensor::Definitions::CustomPower)
  end

  def top10_sensors
    sensors.select(&:top10_enabled?)
  end

  def chart_sensors
    sensors.select(&:chart_enabled?)
  end

  def clear_cache!
    %i[
      @sensors
      @nameable_sensors
      @inverter_sensors
      @custom_inverter_sensors
      @custom_power_sensors
      @house_power_excluded_custom_sensors
      @house_power_included_custom_sensors
    ].each do |var|
      remove_instance_variable(var) if instance_variable_defined?(var)
    end
  end

  private

  def parse_configurations
    Sensor::Registry.all.each do |sensor| # rubocop:disable Rails/FindEach
      env_var = "INFLUX_SENSOR_#{sensor.name.upcase}"
      value = @env[env_var]
      next if value.blank?

      config = ConfigEntry.from_env(value)
      next unless config

      configurations[sensor.name] = config
      log_sensor(sensor.name, value)
    end

    parse_exclude_from_house_power
  end

  def auto_configure_power_splitter_sensors
    Sensor::Registry
      .by_category(:power_splitter)
      .each do |sensor|
        # Only configure if the corresponding base sensor (without "_grid") is configured
        base_sensor_name = sensor.name.to_s.sub('_grid', '').to_sym
        next unless configured?(base_sensor_name)

        # Configure to read from "power_splitter" measurement
        # Permission check will be done later via exists?() method
        configurations[sensor.name] = ConfigEntry.new(
          measurement: 'power_splitter',
          field: sensor.name.to_s,
        )
      end
  end

  def parse_exclude_from_house_power
    return unless configurations[:house_power]

    exclude_value = env['INFLUX_EXCLUDE_FROM_HOUSE_POWER']
    if exclude_value.blank?
      @house_power_exclusions = :unchanged
      return
    end

    excluded_sensors =
      exclude_value
        .split(',')
        .map do |name|
          sensor_name = name.strip.downcase.to_sym
          Sensor::Registry[sensor_name] # This will raise ArgumentError if sensor doesn't exist
        end

    configurations[:house_power].options[:exclude] = excluded_sensors
    @house_power_exclusions = excluded_sensors
  end

  def filter_sensors(&)
    configured_sensors.filter { |sensor| yield(sensor) && sensor.permitted? }
  end

  def configured_sensors
    Sensor::Registry.all.filter { |sensor| exists?(sensor.name) }
  end

  # High-level logging methods (use low-level helpers from ConfigLogger)

  def log_sensor(sensor_name, value)
    @sensor_logs << "- Sensor #{sensor_name.to_s.upcase.ljust(32)} → #{value}"
    check_for_duplicates(sensor_name)
  end

  def log_house_power_status
    return unless @house_power_exclusions

    log_blank
    log_line(
      if @house_power_exclusions == :unchanged
        'HOUSE_POWER is used without modification'
      else
        sensor_names =
          @house_power_exclusions.map { |s| s.name.upcase }.join(', ')
        "HOUSE_POWER will be reduced by #{sensor_names}"
      end,
    )
    log_blank
  end

  def log_configurations
    log_section_header("#{@sensor_logs.size} CONFIGURED SENSORS", char: '·')
    @sensor_logs.each { |log| log_line(log) }
    log_house_power_status

    return if @sensor_warnings.empty?

    log_section_header('⚠️  DUPLICATE CONFIGURATIONS', char: '·')
    @sensor_warnings.each { |warning| log_line("- #{warning}") }
  end

  def check_for_duplicates(sensor_name)
    sensor_measurement = measurement(sensor_name)
    sensor_field = field(sensor_name)

    duplicate =
      configurations.find do |other_name, other_config|
        other_name != sensor_name &&
          other_config.measurement == sensor_measurement &&
          other_config.field == sensor_field
      end

    return unless duplicate

    @sensor_warnings << "#{sensor_name.upcase} and #{duplicate.first.upcase} both use #{sensor_measurement}:#{sensor_field}"
  end
end
