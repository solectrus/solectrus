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
    return { existing_sensors.first => result } if result.is_a?(Numeric)

    # Return nil if all values are nil
    return unless result&.compact.presence

    # Remove the `max_max_` prefix from the keys
    result.transform_keys { |key| key.to_s.sub('max_max_', '').to_sym }
  end

  def cache_options
    { expires_in: 1.day, skip_nil: true }
  end
end
