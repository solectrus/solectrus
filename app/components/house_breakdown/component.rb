class HouseBreakdown::Component < ViewComponent::Base
  include BreakdownTable

  def initialize(data:, timeframe:, sensor_name:)
    super()
    @data = data
    @timeframe = timeframe
    @sensor_name = sensor_name
  end

  attr_reader :data, :timeframe, :sensor_name

  def sorted_segments
    @sorted_segments ||=
      sensor_data
        .sort_by { |_sensor, value, _percent| value }
        .map(&:first)
  end

  def other_sensor
    Sensor::Registry[:house_power_without_custom]
  end

  def other_percent
    data.house_power_without_custom_percent.to_f
  end

  private

  def breakdown_sensors
    Sensor::Config.house_power_included_custom_sensors
  end

  def other_value
    data.house_power_without_custom.to_f
  end
end
