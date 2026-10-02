class Timeframe::Component < ViewComponent::Base
  # A page that is not a sensor page gives its own addresses: `path_for` turns
  # a timeframe into the address of the page, and `select_path` opens the
  # timeframe select. `label_for_all` names the timeframe "all".
  def initialize(timeframe:, forecast_days: nil, path_for: nil, select_path: nil, label_for_all: nil)
    super()
    @timeframe = timeframe
    @forecast_days = forecast_days
    @path_for = path_for
    @select_path = select_path
    @label_for_all = label_for_all
  end
  attr_reader :timeframe, :forecast_days, :label_for_all

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
      timeframe.id == :day && forecast_next?
    end
  end

  def next_path
    return if forecast_mode?

    if timeframe.next
      path_to(timeframe.next)
    elsif forecast_next?
      forecast_path
    end
  end

  def prev_path
    if forecast_mode?
      balance_home_path(sensor_name: 'inverter_power', timeframe: 'day')
    else
      path_to(timeframe.prev)
    end
  end

  def timeframe_select_path
    return @select_path if @select_path
    return if forecast_mode?

    helpers.timeframe_select_path(sensor_name: helpers.sensor_name, timeframe:)
  end

  def paginate_button_classes
    interactive_button_classes(padding_x: 'lg:landscape:px-2')
  end

  def timeframe_link_classes(additional_classes = nil)
    interactive_button_classes(additional_classes: "font-bold lg:font-normal text-base leading-5 #{additional_classes}")
  end

  private

  def path_to(target_timeframe)
    return @path_for.call(target_timeframe) if @path_for

    url_for(
      controller: "#{helpers.controller_namespace}/home",
      sensor_name: helpers.sensor_name,
      timeframe: target_timeframe,
    )
  end

  # Forward from today into the forecast, which only a sensor page has
  def forecast_next?
    @path_for.nil? && Sensor::Config.exists?(:inverter_power_forecast)
  end

  def interactive_button_classes(additional_classes: nil, padding_x: 'px-2')
    [
      "#{padding_x} py-2 rounded-sm",
      'hover:bg-indigo-500 hover:text-gray-200 dark:hover:bg-indigo-950/50 dark:hover:text-gray-300',
      'focus:ring-2 focus:ring-gray-300 focus:ring-offset-0 focus:outline-none dark:focus:ring-gray-400',
      additional_classes,
    ]
  end
end
