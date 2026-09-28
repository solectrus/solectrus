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

  # The name of the period, also for the forecast
  def period_name
    forecast_mode? ? t('forecast.next_days', count: forecast_days) : timeframe.localized
  end

  # First and last date of a period whose name does not say them. A phone
  # hides them.
  def period_dates
    return if forecast_mode?

    case timeframe.id
    when :days, :week
      "#{l timeframe.beginning.to_date, format: :default} – #{l timeframe.ending.to_date, format: :default}"
    when :months
      "#{l timeframe.beginning.to_date, format: :month} – #{l timeframe.ending.to_date, format: :month}"
    when :years
      "#{timeframe.beginning.year} – #{timeframe.ending.year}"
    end
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
      )
    end
  end

  def timeframe_select_path
    return if forecast_mode?

    helpers.timeframe_select_path(sensor_name: helpers.sensor_name, timeframe:)
  end

  def paginate_button_classes
    interactive_button_classes(padding_x: 'lg:landscape:px-2 relative touch-target')
  end

  # A fixed width keeps the arrows in place while one paginates
  def link_width_class
    case timeframe.id
    when :day then 'md:w-72 text-center'
    when :week then 'md:w-80 text-center'
    when :month then 'w-36 text-center'
    when :year then 'w-16 text-center'
    else 'text-center'
    end
  end

  def timeframe_link_classes(additional_classes = nil)
    interactive_button_classes(additional_classes: "font-bold lg:font-normal text-base leading-5 #{additional_classes}")
  end

  private

  def interactive_button_classes(additional_classes: nil, padding_x: 'px-2')
    [
      "#{padding_x} py-2 rounded-sm",
      'hover:bg-indigo-500 hover:text-gray-200 dark:hover:bg-indigo-950/50 dark:hover:text-gray-300',
      'focus:ring-2 focus:ring-gray-300 focus:ring-offset-0 focus:outline-none dark:focus:ring-gray-400',
      additional_classes,
    ]
  end
end
