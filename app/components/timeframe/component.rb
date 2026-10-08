class Timeframe::Component < ViewComponent::Base
  # A page that is not a sensor page gives its own addresses as `page`, see
  # TimeframePage::Sensor
  def initialize(timeframe:, forecast_days: nil, page: nil)
    super()
    @timeframe = timeframe
    @forecast_days = forecast_days
    @page = page
  end
  attr_reader :timeframe, :forecast_days

  def page
    @page ||= TimeframePage::Sensor.new(
      namespace: helpers.controller_namespace,
      sensor_name: helpers.sensor_name,
      params: helpers.selection_params,
    )
  end

  delegate :label_for_all, to: :page

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
      timeframe.id == :day && page.forecast?
    end
  end

  def next_path
    return if forecast_mode?

    if timeframe.next
      page.path(timeframe.next)
    elsif page.forecast?
      forecast_path
    end
  end

  def prev_path
    if forecast_mode?
      balance_home_path(sensor_name: 'inverter_power', timeframe: 'day')
    else
      page.path(timeframe.prev)
    end
  end

  def timeframe_select_path
    page.path(timeframe) unless forecast_mode?
  end

  def paginate_button_classes
    interactive_button_classes(padding_x: 'lg:landscape:px-2')
  end

  def timeframe_link_classes(additional_classes = nil)
    interactive_button_classes(additional_classes: "font-bold lg:font-normal text-base leading-5 #{additional_classes}")
  end

  LABEL_WIDTHS = { day: 'md:w-72', week: 'w-36', month: 'w-36', year: 'w-16' }.freeze
  private_constant :LABEL_WIDTHS

  def label_classes
    "text-center #{LABEL_WIDTHS[timeframe.id]}"
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
