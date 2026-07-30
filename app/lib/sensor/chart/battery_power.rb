class Sensor::Chart::BatteryPower < Sensor::Chart::Base
  # Discharging is negated to grow downward (see #transform_data).
  include Sensor::Chart::Concerns::OppositeDirectionBars

  private

  def chart_sensor_names
    %i[battery_charging_power battery_discharging_power]
  end

  # Discharging grows downward, so it is negated -- but only after the base
  # class has clamped the values to their sensor's range. Skipping that clamp
  # let a Power Splitter share that overshoots its own total (see
  # SummaryBuilder#fix_grid_sensors_against_base_sensors) turn negative, and
  # negating it grew the bar upward into the charging half of the chart.
  def transform_data(data, sensor_name)
    validated = super
    return validated unless sensor_name == :battery_discharging_power

    validated.map { |value| -value if value }
  end
end
