class Sensor::Chart::HeatpumpTankTemp < Sensor::Chart::MinmaxBase
  def chart_sensor_names
    @chart_sensor_names ||= begin
      names = %i[heatpump_tank_temp]
      names << :heatpump_tank_temp_setpoint unless use_sql_for_timeframe?

      names.select { |name| Sensor::Config.exists?(name) }
    end
  end

  def suggested_min
    20
  end

  private

  def style_for_sensor(sensor)
    if sensor.name == :heatpump_tank_temp_setpoint
      super.merge(
        label: sensor.display_name(:short),
        fill: false,
        tension: 0,
        borderWidth: 2,
        borderDash: [6, 4],
        noGradient: true,
        order: 0,
      )
    else
      super
    end
  end
end
