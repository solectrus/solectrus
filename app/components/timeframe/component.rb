class Timeframe::Component < ViewComponent::Base
  def initialize(timeframe:, forecast_days: nil, chart_name: nil)
    super()
    @timeframe = timeframe
    @forecast_days = forecast_days
    @chart_name = chart_name
  end
  attr_reader :timeframe, :forecast_days, :chart_name

  def forecast_mode?
    forecast_days.present?
  end

  # Check if navigation is possible at all
  # - timeframe can be paginated, or
  # - in forecast mode
  def can_navigate?
    timeframe.can_paginate? || forecast_mode?
  end

  # Check if backward navigation is possible
  # - in forecast mode (back to today), or
  # - previous timeframe exists
  def can_navigate_backward?
    forecast_mode? || timeframe.prev
  end

  # Check if forward navigation is possible
  # Forward navigation into the future is only allowed for:
  # - not in forecast mode
  # - inverter category sensors (no other sensors support future data)
  # - day timeframe only (not week, month, year, etc.)
  # - and next timeframe exists
  def can_navigate_forward?
    return false if forecast_mode?

    if timeframe.next
      true
    else
      timeframe.id == :day && Sensor::Config.exists?(:inverter_power_forecast)
    end
  end

  def next_path
    return if forecast_mode?

    if timeframe.next
      url_for(
        controller: "#{helpers.controller_namespace}/home",
        sensor_name: helpers.sensor_name,
        timeframe: timeframe.next,
        chart_name:,
      )
    elsif Sensor::Config.exists?(:inverter_power_forecast)
      forecast_path
    end
  end

  def prev_path
    if forecast_mode?
      balance_home_path(sensor_name: 'inverter_power', timeframe: 'day')
    else
      url_for(
        controller: "#{helpers.controller_namespace}/home",
        sensor_name: helpers.sensor_name,
        timeframe: timeframe.prev,
        chart_name:,
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
