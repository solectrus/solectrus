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
        calculate_peak(start)
      end
  end

  private

  def existing_sensors
    @existing_sensors ||=
      sensors.select do |sensor|
        SensorConfig.x.exists?(sensor) &&
          Summary.column_names.include?("max_#{sensor}")
      end
  end

  def calculate_peak(start)
    result =
      Summary.where(date: start..).calculate_all(
        *existing_sensors.map { |sensor| :"max_max_#{sensor}" },
      )

    # `calculate_all` returns a single value if only one sensor is provided
    # Ensure the result is a hash with the sensor name as the key
    if result.is_a?(Numeric) && existing_sensors.one?
      return { existing_sensors.first => result }
    end

    # Return nil if all values are nil
    result if result.values.any?
  end

  def cache_options
    { expires_in: 1.day }
  end
end
