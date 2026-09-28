class Sensor::SummaryInvalidator
  extend Sensor::ConfigLogger

  # Ensures summaries are valid, resets them if configuration has changed
  def self.ensure_valid!
    current_config = build_config
    stored_config = Setting.summary_config

    # Convert stored config to comparable format (handles string/symbol key differences)
    normalized_stored_config = normalize_config(stored_config)
    normalized_current_config = normalize_config(current_config)

    # Check what kind of configuration change occurred
    if stored_config.nil?
      # First run, no stored config yet
      Setting.summary_config = current_config
      log_line 'First run, configuration initialized'
    elsif normalized_stored_config == normalized_current_config
      log_line 'Configuration unchanged, summaries still valid'
    else
      # Save changed config
      Setting.summary_config = current_config

      if relevant_changes?(normalized_stored_config, normalized_current_config)
        # Existing summaries are no longer valid. Rebuild required.
        Summary.reset!
        log_line 'Configuration changed, rebuilding summaries is required'
      else
        # New sensors without history, removed sensors or other non-critical changes
        log_line 'Configuration changed, but summaries still valid'
      end
    end
  end

  private_class_method def self.build_config
    {
      #
      # Version of the configuration. Update this if the logic of the
      # summaries has changed. This will invalidate all existing summaries
      version: '2025-10-11',
      #
      # The date column depends on the current timezone.
      # If the timezone changes, the summaries are no longer valid
      time_zone: Time.zone.name,
      #
      # Hash of all sensors that are stored in summaries with their configuration.
      # If any sensor configuration changes, the summaries become invalid
      sensors_in_summary: sensors_in_summary_config,
      #
      # List of sensors excluded from house_power calculation.
      # If this list changes, house_power calculations become invalid
      excluded_from_house_power:
        Sensor::Config.house_power_excluded_sensors.map(&:name),
    }
  end

  private_class_method def self.sensors_in_summary_config
    # Returns a hash of sensors with InfluxDB configuration that affects summary validity
    # Only includes sensors that have actual InfluxDB configuration (not calculated sensors)
    Sensor::Config
      .sensors
      .select(&:store_in_summary?)
      .filter_map do |sensor|
        mapping = Sensor::Config.mapping(sensor.name)
        next unless mapping # Skip sensors without InfluxDB configuration (calculated sensors)

        [sensor.name, mapping]
      end
      .to_h
  end

  private_class_method def self.normalize_config(config)
    # Normalize config for comparison by converting to JSON and parsing back
    # This ensures consistent string keys and values regardless of source format
    config ? JSON.parse(config.to_json) : nil
  end

  private_class_method def self.relevant_changes?(old_config, new_config)
    # Compare base configuration (version, time_zone, excluded_from_house_power)
    base_keys = %w[version time_zone excluded_from_house_power]
    return true if base_keys.any? { |key| old_config[key] != new_config[key] }

    old_sensors = old_config['sensors_in_summary'] || {}
    new_sensors = new_config['sensors_in_summary'] || {}

    changed_sensor?(old_sensors, new_sensors) ||
      changed_inverter_power_source?(old_sensors, new_sensors) ||
      history_changed?(old_sensors, new_sensors)
  end

  # A sensor that exists in both configurations but reads another field
  private_class_method def self.changed_sensor?(old_sensors, new_sensors)
    common_sensors = old_sensors.keys & new_sensors.keys
    common_sensors.any? { |sensor| old_sensors[sensor] != new_sensors[sensor] }
  end

  # inverter_power is stored in every summary, whether measured or calculated
  # as the sum of the single inverters. A switch between the two changes the
  # stored value.
  private_class_method def self.changed_inverter_power_source?(
    old_sensors,
    new_sensors
  )
    old_sensors.key?('inverter_power') != new_sensors.key?('inverter_power')
  end

  # A sensor that is added or removed changes the summaries only if it has
  # data for a day before today. Today does not count: its summary is rebuilt
  # anyway.
  #
  # The configuration cannot tell this apart. A new device has no history, but
  # a new sensor can also point to a field with years of data.
  private_class_method def self.history_changed?(old_sensors, new_sensors)
    return false unless Summary.exists?(['date < ?', Date.current])

    added_with_history?(new_sensors.keys - old_sensors.keys) ||
      removed_inverters_in_summaries?(old_sensors, new_sensors)
  end

  # An added sensor is missing in the existing summaries
  private_class_method def self.added_with_history?(sensor_names)
    return false if sensor_names.empty?

    first_seen = Sensor::Query::FirstSeen.new(sensor_names.map(&:to_sym)).call
    first_seen.any? do |sensor_name, time|
      (time < Date.current.beginning_of_day).tap do |found|
        log_line "#{sensor_name} has data since #{time.to_date}" if found
      end
    end
  rescue StandardError => e
    # Rebuilding without need costs time, wrong summaries cost trust
    log_line "Cannot check added sensors in InfluxDB: #{e.message}"
    true
  end

  # A removed single inverter is still part of the calculated inverter_power
  # in the existing summaries. Other removed sensors are simply no longer read.
  private_class_method def self.removed_inverters_in_summaries?(
    old_sensors,
    new_sensors
  )
    return false if new_sensors.key?('inverter_power')

    removed_inverters =
      (old_sensors.keys - new_sensors.keys).grep(/\Ainverter_power_\d+\z/)
    return false if removed_inverters.empty?

    SummaryValue
      .where(field: removed_inverters, aggregation: :sum)
      .where(date: ...Date.current)
      .where('value > 0')
      .exists?
      .tap do |found|
        if found
          log_line "#{removed_inverters.join(', ')} part of existing summaries"
        end
      end
  end
end
