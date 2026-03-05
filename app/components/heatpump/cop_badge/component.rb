class Heatpump::CopBadge::Component < ViewComponent::Base
  def initialize(data:, timeframe:, css_class: nil)
    super()
    @data = data
    @timeframe = timeframe
    @css_class = css_class
  end

  attr_reader :data, :timeframe, :css_class

  def render?
    data.heatpump_cop&.positive?
  end

  def link_url
    helpers.url_for(controller: 'home', sensor_name: 'heatpump_cop', timeframe:)
  end

  def chart_url
    helpers.heatpump_charts_path(sensor_name: 'heatpump_cop', timeframe:)
  end

  def link_class
    class_names('block focus:outline-none', css_class)
  end
end
