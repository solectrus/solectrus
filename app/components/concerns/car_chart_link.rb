# A link on the car page that loads the chart of a sensor in place. The
# component needs a timeframe.
module CarChartLink
  private

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
