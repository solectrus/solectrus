class Sensor::Chart::BatteryPower < Sensor::Chart::Base
  # Bars grow in opposite directions (not stacked), so gradient looks good
  def style_for_sensor(sensor)
    super.merge(noGradient: false)
  end

  private

  def chart_sensor_names
    %i[battery_charging_power battery_discharging_power]
  end

  # Transform import data to negative values
  def transform_data(data, sensor_name)
    case sensor_name
    when :battery_discharging_power
      data.map { |value| -value if value } # Make discharging negative
    else
      data # Charging stays positive
    end
  end
end
