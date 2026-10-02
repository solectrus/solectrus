# A link on the car page that loads the chart of a sensor in place. The
# component needs a timeframe.
module CarChartLink
  private

  # The sensor whose chart a click loads, or nil when its chart cannot draw
  # the timeframe. A rate, the distance and the driving cost need a day at
  # least.
  def chart_sensor_name(sensor_name)
    sensor_name if Sensor::Registry[sensor_name.to_sym].chart(timeframe).supported?
  end

  def chart_link_url(sensor_name)
    helpers.cars_home_path(sensor_name:, timeframe:)
  end

  def chart_link_data(sensor_name)
    {
      turbo_prefetch: 'false',
      action: 'stats-with-chart--component#loadChart',
      stats_with_chart__component_sensor_name_param: sensor_name,
      stats_with_chart__component_chart_url_param:
        helpers.cars_charts_path(sensor_name:, timeframe:),
    }
  end
end
