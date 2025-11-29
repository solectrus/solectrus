class Sensor::Chart::BatteryChargingPower < Sensor::Chart::BatteryPower
  private

  def chart_sensor_names
    if splitting_allowed?
      %i[
        battery_charging_power_grid
        battery_charging_power_pv
        battery_discharging_power
      ]
    else
      super
    end
  end

  def style_for_sensor(sensor)
    if splitting_allowed?
      super.merge(stack: true)
    else
      super
    end
  end

  def splitting_allowed?
    return false if timeframe.short?
    return false unless ApplicationPolicy.power_splitter?

    Sensor::Config.exists?(:battery_charging_power_grid)
  end
end
