class Calculator::QueryInfluxDiff < Calculator::Base
  def initialize(timeframe)
    super()

    @timeframe = timeframe
    build_context Flux::Diff.new(sensors:).call(timeframe:)
  end

  attr_reader :timeframe

  private

  def build_context(data)
    sensors.each { |sensor| build_method(:"diff_#{sensor}", data) }

    # Add dummy methods for sensors that are not available
    (ALL_SENSORS - sensors).each do |sensor|
      build_method(:"diff_#{sensor}", {})
    end
  end

  ALL_SENSORS = %i[car_mileage].freeze
  private_constant :ALL_SENSORS

  def sensors
    @sensors ||=
      ALL_SENSORS.select do |sensor|
        SensorConfig.x.exists?(sensor, check_policy: false)
      end
  end
end
