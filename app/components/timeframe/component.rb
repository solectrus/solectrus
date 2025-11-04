class Timeframe::Component < ViewComponent::Base
  def initialize(timeframe:)
    super()
    @timeframe = timeframe
  end
  attr_reader :timeframe

  def next_path
    url_for(
      controller: "#{helpers.controller_namespace}/home",
      sensor_name: helpers.sensor_name,
      timeframe: timeframe.next,
    )
  end

  def prev_path
    url_for(
      controller: "#{helpers.controller_namespace}/home",
      sensor_name: helpers.sensor_name,
      timeframe: timeframe.prev,
    )
  end

  def timeframe_select_path
    helpers.timeframe_select_path(sensor_name: helpers.sensor_name, timeframe:)
  end
end
