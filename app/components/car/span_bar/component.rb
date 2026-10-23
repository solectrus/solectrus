# Where a value lies in the span of its periods (see Car::Spans): a short track
# from the bad end on the left to the good end on the right, with a mark at
# the value. `better` names the good end: a low consumption is good, so its
# track runs from the highest value to the lowest. The bar shows the place
# alone. The best and the worst period stand in the insights of the chart
# (see Car::Insights::Component).
class Car::SpanBar::Component < ViewComponent::Base
  # The class names stay literal, so Tailwind finds them
  TRACK_CLASSES =
    'bg-linear-to-r/oklch from-signal-negative via-signal-warning to-signal-positive'.freeze
  private_constant :TRACK_CLASSES

  # `better` is :lower or :higher
  def initialize(value:, span:, better:)
    super()
    @value = value
    @span = span
    @better = better
  end

  def track_classes = TRACK_CLASSES

  # The position of the mark in percent of the track, from the bad end
  def position
    @position ||=
      begin
        share = ((@value - @span.min) * 100.0 / (@span.max - @span.min)).clamp(0, 100)
        (@better == :lower ? 100 - share : share).round(1)
      end
  end
end
