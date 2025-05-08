class PowerPeak
  def initialize(sensors:)
    @sensors = sensors
  end

  attr_reader :sensors

  def call(start:)
    return if existing_sensors.empty?

    start = start&.to_date
    Rails
      .cache
      .fetch(cache_key(start), cache_options) do
        query(start).symbolize_keys.presence
      end
  end

  private

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
    "power_peak:#{start}:#{Digest::SHA256.hexdigest(sorted)}"
  end
end
