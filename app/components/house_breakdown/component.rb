class HouseBreakdown::Component < ViewComponent::Base
  def initialize(data:, timeframe:, sensor_name:)
    super()
    @data = data
    @timeframe = timeframe
    @sensor_name = sensor_name
  end

  attr_reader :data, :timeframe, :sensor_name

  def table_rows
    @table_rows ||= build_table_rows
  end

  def sorted_segments
    @sorted_segments ||=
      sensor_data
        .sort_by { |_sensor, value, _percent| value }
        .map(&:first)
  end

  def sensor_count
    Sensor::Config.house_power_included_custom_sensors.length
  end

  def other_sensor
    Sensor::Registry[:house_power_without_custom]
  end

  def other_percent
    data.house_power_without_custom_percent.to_f
  end

  # Determine a common scaling for all values so units are consistent
  # (e.g. all kWh or all Wh, never mixed)
  def common_scaling
    @common_scaling ||= determine_common_scaling
  end

  private

  def build_table_rows
    rows = sensor_data.filter_map do |sensor, value, percent|
      next if value.zero? && percent.zero?

      { sensor:, percent: }
    end
    rows.sort_by { |r| -r[:percent] }
  end

  def sensor_data
    @sensor_data ||=
      Sensor::Config.house_power_included_custom_sensors.map do |sensor|
        [
          sensor,
          data.public_send(sensor.name).to_f,
          data.public_send(:"#{sensor.name}_percent").to_f,
        ]
      end
  end

  def determine_common_scaling
    values = sensor_data.filter_map { |_s, v, _p| v if v.nonzero? }

    other_val = data.house_power_without_custom.to_f
    values << other_val if other_val.nonzero?

    return :auto if values.empty?

    scales = values.map { |v| scale_for_value(v) }
    scales.tally.max_by(&:last).first
  end

  def scale_for_value(value)
    formatter = Sensor::UnitFormatter.new(unit: :watt, value:, scaling: :auto)
    case formatter.divisor
    when 1 then :off
    when 1_000 then :kilo
    else :mega
    end
  end
end
