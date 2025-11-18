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
        # New sensors added/removed or other non-critical changes
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
    # Compare configurations, ignoring additions/removals of sensors
    # Compare base configuration (version, time_zone, excluded_from_house_power)
    base_keys = %w[version time_zone excluded_from_house_power]
    return true if base_keys.any? { |key| old_config[key] != new_config[key] }

    # Compare only sensors that exist in both configurations
    old_sensors = old_config['sensors_in_summary'] || {}
    new_sensors = new_config['sensors_in_summary'] || {}
    common_sensors = old_sensors.keys & new_sensors.keys

    # Check if any common sensor configuration has changed
    common_sensors.any? { |sensor| old_sensors[sensor] != new_sensors[sensor] }
  end
end
