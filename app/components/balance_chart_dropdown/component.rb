class BalanceChartDropdown::Component < ChartDropdownBase::Component
  CHART_SENSORS = %i[
    autarky
    battery_power
    battery_soc
    car_battery_soc
    case_temp
    co2_reduction
    grid_costs
    grid_power
    grid_revenue
    heatpump_power
    house_power
    power_balance
    inverter_power
    savings
    self_consumption_quote
    total_costs
    wallbox_power
  ].freeze
  private_constant :CHART_SENSORS

  private

  def sensor_names
    @sensor_names ||= Sensor::Config.chart_sensors.filter_map { |sensor| sensor.name if include_sensor_in_chart?(sensor) }
  end

  def menu_items
    @menu_items ||= sensor_names.sort_by { |sensor_name| Sensor::Registry[sensor_name].display_name(:long).downcase }
  end

  def include_sensor_in_chart?(sensor)
    return true if CHART_SENSORS.include?(sensor.name)
    return true if Sensor::Config.house_power_excluded_custom_sensors.include?(sensor)

    sensor.is_a?(Sensor::Definitions::CustomInverterPower) &&
      !Setting.inverter_as_total
  end
end
