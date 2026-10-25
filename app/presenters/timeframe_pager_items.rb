# The items of the period of a phone (see Timeframe::Pager::Component), for a
# page with a timeframe: a home page, a list or the forecast.
#
# `path` gives the address of the page in a timeframe. `forecast_path` is
# where the day after today leads, if anywhere. `period_item` changes the
# item of the period, for example its name.
class TimeframePagerItems
  def initialize(timeframe:, path:, forecast_path: nil, period_item: {})
    @timeframe = timeframe
    @path = path
    @forecast_path = forecast_path
    @period_item = period_item
  end

  def to_h
    { period:, arrows: }
  end

  private

  attr_reader :timeframe

  # The live view has no period to name
  def period
    return if timeframe.now?

    { name: timeframe.localized, href: @path.call(timeframe.to_param), **@period_item }
  end

  # The arrows turn the page, as a swipe and the arrows of a wide screen do.
  # The live view turns as today does: back to yesterday and on into the
  # forecast.
  def arrows
    return { prev: @path.call(Date.yesterday.to_s), next: @forecast_path } if timeframe.now?

    { prev: prev_path, next: next_path }
  end

  def prev_path
    @path.call(timeframe.prev.to_s) if timeframe.can_paginate? && timeframe.prev
  end

  def next_path
    return unless timeframe.can_paginate?
    return @path.call(timeframe.next.to_s) if timeframe.next

    @forecast_path if timeframe.day?
  end
end
