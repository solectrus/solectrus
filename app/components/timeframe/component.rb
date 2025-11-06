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

  def paginate_button_classes
    interactive_button_classes
  end

  def timeframe_link_classes(additional_classes = nil)
    interactive_button_classes(additional_classes)
  end

  private

  def interactive_button_classes(additional_classes = nil)
    [
      'px-2 py-1 rounded-sm',
      'hover:bg-indigo-500 hover:text-white dark:hover:bg-indigo-800 dark:hover:text-gray-400',
      'focus:ring-2 focus:ring-gray-300 focus:ring-offset-0 focus:outline-none dark:focus:ring-gray-400',
      additional_classes,
    ]
  end
end
