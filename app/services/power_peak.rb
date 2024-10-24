class PowerPeak
  def initialize(sensors:)
    @sensors = sensors
  end

  attr_reader :sensors

  def call(start:)
    return {} if existing_sensors.empty?

    Rails
      .cache
      .fetch(['power_peak', existing_sensors], cache_options) do
        Summary.where(date: start..).calculate_all(
          *existing_sensors.map { |sensor| :"max_max_#{sensor}" },
        )
      end
  end

  private

  def existing_sensors
    @existing_sensors ||=
      sensors.select { |sensor| SensorConfig.x.exists?(sensor) }
  end

  def cache_options
    { expires_in: 1.day }
  end
end
