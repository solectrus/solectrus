# Where a value lies in the span of its periods (see Car::Spans), in the
# tooltip of a figure of the overview: a gray track from the bad end on the
# left to the good end on the right, with a mark at the value, and below each
# end its number and its period. `better` names the good end: a low
# consumption is good, so its track runs from the highest value to the
# lowest. The best and the worst period stand in the insights of the chart
# too (see Car::Insights::Component). A sheet lists them as `rows` with a
# link, like Insights::Row::Component, in place of the periods below the
# bar.
class Car::SpanBar::Component < ViewComponent::Base
  # `better` is :lower or :higher. `precision` is the number of decimals of
  # an end.
  def initialize(value:, span:, better:, precision:, rows: [])
    super()
    @value = value
    @span = span
    @better = better
    @precision = precision
    @rows = rows
  end

  attr_reader :rows

  # The name of a period, a day in short, because the long day has its
  # weekday too
  def self.period(timeframe) = timeframe.day? ? I18n.l(timeframe.date) : timeframe.localized

  # The position of the mark in percent of the track, from the bad end
  def position
    @position ||=
      begin
        share = ((@value - @span.min) * 100.0 / (@span.max - @span.min)).clamp(0, 100)
        (@better == :lower ? 100 - share : share).round(1)
      end
  end

  # [number, period] of the bad and of the good end
  def ends
    ends = [[number(@span.min), self.class.period(@span.min_timeframe)], [number(@span.max), self.class.period(@span.max_timeframe)]]
    @better == :lower ? ends.reverse : ends
  end

  private

  def number(value) = helpers.number_with_precision(value, precision: @precision)
end
