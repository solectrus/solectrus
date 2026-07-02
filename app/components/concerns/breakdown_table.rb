module BreakdownTable
  extend ActiveSupport::Concern

  def table_rows
    @table_rows ||= build_table_rows
  end

  def sensor_count
    breakdown_sensors.length
  end

  # Determine a common scaling for all values so units are consistent
  # (e.g. all kWh or all Wh, never mixed)
  def common_scaling
    @common_scaling ||= determine_common_scaling
  end

  private

  # The including component supplies the sensors that make up the breakdown
  # (e.g. custom inverter strings or house sub-consumers) and the value of the
  # unassigned remainder ("other") segment.
  def breakdown_sensors
    raise NotImplementedError
  end

  def other_value
    raise NotImplementedError
  end

  def build_table_rows
    rows = sensor_data.filter_map do |sensor, value, percent|
      next if value.zero? && percent.zero?

      { sensor:, percent: }
    end
    rows.sort_by { |r| -r[:percent] }
  end

  def sensor_data
    @sensor_data ||=
      breakdown_sensors.map do |sensor|
        [
          sensor,
          data.public_send(sensor.name).to_f,
          data.public_send(:"#{sensor.name}_percent").to_f,
        ]
      end
  end

  def determine_common_scaling
    values = sensor_data.filter_map { |_s, v, _p| v if v.nonzero? }
    values << other_value if other_value.nonzero?

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
