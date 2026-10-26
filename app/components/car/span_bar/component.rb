# Where a value lies in the span of its periods (see Car::Spans): a short
# gray track from the bad end on the left to the good end on the right, with
# a mark at the value and the number of each end below it. `better` names
# the good end: a low consumption is good, so its track runs from the highest
# value to the lowest. The best and the worst period stand in the insights
# of the chart (see Car::Insights::Component).
class Car::SpanBar::Component < ViewComponent::Base
  # `better` is :lower or :higher. `precision` is the number of decimals of
  # an end.
  def initialize(value:, span:, better:, precision:)
    super()
    @value = value
    @span = span
    @better = better
    @precision = precision
  end

  # The position of the mark in percent of the track, from the bad end
  def position
    @position ||=
      begin
        share = ((@value - @span.min) * 100.0 / (@span.max - @span.min)).clamp(0, 100)
        (@better == :lower ? 100 - share : share).round(1)
      end
  end

  # The numbers of the bad and of the good end
  def ends
    ends = [number(@span.min), number(@span.max)]
    @better == :lower ? ends.reverse : ends
  end

  private

  def number(value) = helpers.number_with_precision(value, precision: @precision)
end
