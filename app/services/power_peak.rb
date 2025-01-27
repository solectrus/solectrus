class PowerPeak
  def initialize(sensors:)
    @sensors = sensors
  end

  attr_reader :sensors

  def call(start:)
    return if existing_sensors.empty?

    Rails
      .cache
      .fetch(['power_peak', existing_sensors], cache_options) do
        query(start).symbolize_keys.presence
      end
  end

  private

  def existing_sensors
    @existing_sensors ||=
      sensors.select { |sensor| SensorConfig.x.exists?(sensor) }
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
end
