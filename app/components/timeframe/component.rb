class Timeframe::Component < ViewComponent::Base
  def initialize(timeframe:, forecast_days: nil)
    super()
    @timeframe = timeframe
    @forecast_days = forecast_days
  end
  attr_reader :timeframe, :forecast_days

  def forecast_mode?
    forecast_days.present?
  end

  def next_path
    return if forecast_mode?

    url_for(
      controller: "#{helpers.controller_namespace}/home",
      sensor_name: helpers.sensor_name,
      timeframe: timeframe.next,
    )
  end

  def prev_path
    if forecast_mode?
      balance_home_path(sensor_name: 'inverter_power', timeframe: 'day')
    else
      url_for(
        controller: "#{helpers.controller_namespace}/home",
        sensor_name: helpers.sensor_name,
        timeframe: timeframe.prev,
      )
    end
  end

  def timeframe_select_path
    return if forecast_mode?

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
      'px-2 py-2 rounded-sm',
      'hover:bg-indigo-500 hover:text-gray-200 dark:hover:bg-indigo-950/50 dark:hover:text-gray-300',
      'focus:ring-2 focus:ring-gray-300 focus:ring-offset-0 focus:outline-none dark:focus:ring-gray-400',
      additional_classes,
    ]
  end
end
