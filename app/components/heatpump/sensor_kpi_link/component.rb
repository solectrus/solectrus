class Heatpump::SensorKpiLink::Component < ViewComponent::Base
  def initialize(data:, sensor_name:, timeframe:, chart_url:, url: nil, css_class: nil)
    super()
    @data = data
    @sensor_name = sensor_name
    @timeframe = timeframe
    @chart_url = chart_url
    @url = url
    @css_class = css_class
  end

  attr_reader :data, :sensor_name, :timeframe, :chart_url, :css_class

  def render?
    value.present?
  end

  def link_url
    @url || helpers.url_for(controller: 'home', sensor_name:, timeframe:)
  end

  def value
    @value ||= data.public_send(sensor_name)
  end

  def sensor_value_context
    timeframe.now? ? :rate : :total
  end

  def title
    Sensor::Registry[sensor_name].display_name(:short)
  end

  def link_data
    {
      turbo_prefetch: 'false',
      'stats-with-chart--component-target': 'current',
      'sensor-name': sensor_name,
      value:,
      time: data.time.to_i,
      action: 'stats-with-chart--component#loadChart',
      stats_with_chart__component_sensor_name_param: sensor_name,
      stats_with_chart__component_chart_url_param: chart_url,
    }
  end
end
