# A link on the car page that loads the chart of a sensor in place. The
# component needs a timeframe, and the selected cars for #chart_sensor_name.
module CarChartLink
  private

  # The sensor whose chart a click loads, or nil when its chart cannot draw
  # the timeframe or the selected cars. A rate and the driving cost need a
  # longer timeframe than a day. A card asks for a sensor several times, and
  # each answer builds the chart.
  def chart_sensor_name(sensor_name)
    @chart_sensor_names ||= Hash.new do |names, name|
      names[name] = (name if Sensor::Registry[name.to_sym].chart(timeframe, **helpers.chart_options).supported?)
    end
    @chart_sensor_names[sensor_name]
  end

  # The tag and the options of a block that loads the chart of the sensor, or
  # of a plain block without a sensor. `link_class` applies to the link alone.
  def chart_wrapper(sensor_name, link_class: nil, data: {}, **options)
    return [:div, { **options, data: }] unless sensor_name

    [:a, { **options, href: chart_link_url(sensor_name), class: [*options[:class], link_class].compact, data: data.merge(chart_link_data(sensor_name)) }]
  end

  def chart_link_url(sensor_name)
    helpers.cars_home_path(sensor_name:, timeframe:, **helpers.selection_params)
  end

  def chart_link_data(sensor_name)
    {
      turbo_prefetch: 'false',
      action: 'stats-with-chart--component#loadChart',
      stats_with_chart__component_sensor_name_param: sensor_name,
      stats_with_chart__component_chart_url_param: chart_url(sensor_name),
    }
  end

  # The url that the chart of the sensor loads from
  def chart_url(sensor_name)
    helpers.cars_charts_path(sensor_name:, timeframe:, **helpers.selection_params)
  end
end
