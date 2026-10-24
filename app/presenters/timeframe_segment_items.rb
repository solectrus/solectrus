# The items of the timeframe of a phone in one row (see
# Timeframe::Segments::Component), for a page with a timeframe: a home page or
# a list.
#
# `period` is the period that the third segment names: the one of the page, or
# another one while the page shows the live view or today. `path` gives the
# address of the page in a timeframe. `live` is the item of the live view, nil
# for a page without one, which shows it disabled. `forecast_path` is where
# the day after today leads, if anywhere. `period_item` changes the item of
# the period, for example its name.
class TimeframeSegmentItems
  def initialize(timeframe:, period:, path:, live: nil, forecast_path: nil, period_item: {})
    @timeframe = timeframe
    @period = period
    @path = path
    @live = live
    @forecast_path = forecast_path
    @period_item = period_item
  end

  def to_h
    {
      live: @live || { name: I18n.t('data.now'), href: nil, current: false },
      today: { name: I18n.t('timeframe.day'), href: @path.call('day'), current: timeframe.today? },
      period: { name: period_name, href: @path.call(period.to_param), current: timeframe.period?, **@period_item },
      arrows:,
    }
  end

  private

  attr_reader :timeframe, :period

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

  # The segment has half of the width of a phone, so a day or a range carries
  # its year only when that is not the current one
  def period_name
    return I18n.t('data.all') if period.all?
    return day_name(period.date) if period.day?
    return range_name if period.range?

    period.localized
  end

  def day_name(date) = I18n.l(date, format: date.year == Date.current.year ? :weekday : :default)

  # A range within one year names the year once, at its end
  def range_name
    first = period.beginning.to_date
    last = period.ending.to_date
    return period.localized if first.year != last.year

    name = [first, last].map { I18n.l(it, format: :short).strip }.join(' – ')
    last.year == Date.current.year ? name : "#{name} #{last.year}"
  end
end
