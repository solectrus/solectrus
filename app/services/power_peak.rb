class PowerPeak
  def initialize(sensors:)
    @sensors = sensors
  end

  attr_reader :sensors

  def call(start:)
    return if existing_sensors.empty?

    start = start&.to_date
    Rails.cache.fetch(cache_key(start), cache_options) { peaks(start:) }
  end

  private

  def peaks(start:)
    query(start).symbolize_keys.presence.tap do |raw|
      if raw && SensorConfig.x.multi_inverter?
        # Ensure there is a total inverter power value
        raw[:inverter_power] ||= SensorConfig
          .x
          .existing_custom_inverter_sensor_names
          .filter_map { raw[it] }
          .sum # not totally correct, but close enough
      end
    end
  end

  def existing_sensors
    @existing_sensors ||=
      sensors.select do |sensor|
        SensorConfig.x.exists?(sensor) &&
          SensorConfig::CALCULATED_SENSORS.exclude?(sensor)
      end
  end

  def query(start)
    SummaryValue
      .where(date: start.., field: existing_sensors, aggregation: :max)
      .group(:field)
      .maximum(:value)
  end

  def cache_options
    { expires_in: 1.day, skip_nil: true }
  end

  def cache_key(start)
    sorted = existing_sensors.sort.join(',')
    "power_peak:v2:#{start}:#{Digest::SHA256.hexdigest(sorted)}"
  end
end
