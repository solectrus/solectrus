# A value in the span of its periods (see Car::Spans): a track from the bad
# end on the left to the good end on the right, with a mark above it at the
# value and the two ends below. The mark takes the color of its third.
# `better` names the good end: a high range is good, so its track runs from
# the lowest value to the highest, but a low consumption is good, so its
# track runs from the highest value to the lowest. The mark points at the
# track and has no handle, so the bar does not look like a slider.
#
# Each end names the period of its value in a tooltip and links to it. The
# end of the shown period says so and has no link, because it would lead to
# the same page.
class Car::SpanBar::Component < ViewComponent::Base
  # An end of the span: :min or :max, its value and its timeframe
  End = Data.define(:extreme, :value, :timeframe)
  private_constant :End

  # The class names stay literal, so Tailwind finds them
  TRACK_CLASSES =
    'bg-linear-to-r/oklch from-signal-negative via-signal-warning to-signal-positive'.freeze
  private_constant :TRACK_CLASSES

  MARKS = %w[text-signal-negative text-signal-warning text-signal-positive].freeze
  private_constant :MARKS

  END_CLASSES =
    'click-animation rounded-sm hover:text-slate-600 dark:hover:text-slate-300 ' \
    'focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400'.freeze
  private_constant :END_CLASSES

  # `better` is :lower or :higher. `shown` is the timeframe of the page,
  # `format` formats a value of the span, and `url` gives the page of a
  # timeframe.
  def initialize(value:, span:, better:, shown:, format:, url:)
    super()
    @value = value
    @span = span
    @better = better
    @shown = shown
    @format = format
    @url = url
  end

  # The bad end on the left, the good end on the right
  def ends
    (lower? ? %i[max min] : %i[min max]).map do |extreme|
      End.new(extreme:, value: @span.public_send(extreme), timeframe: @span.public_send(:"#{extreme}_timeframe"))
    end
  end

  def label(span_end) = @format.call(span_end.value)

  def shown?(span_end) = span_end.timeframe.to_s == @shown.to_s

  def track_classes = TRACK_CLASSES

  # The tag and the options of an end. A tap on a link opens its period, so
  # its tooltip needs a long press. The end of the shown period opens its
  # tooltip with a tap.
  def end_tag(span_end)
    if shown?(span_end)
      [:span, { class: 'cursor-default', data: { controller: 'tooltip', tooltip_touch_value: 'true' } }]
    else
      [:a, { href: @url.call(span_end.timeframe), class: END_CLASSES, data: { controller: 'tooltip', tooltip_force_tap_to_close_value: false, tooltip_touch_value: 'long' } }]
    end
  end

  # The position of the mark in percent of the track, from the bad end
  def position
    @position ||=
      begin
        share = ((@value - @span.min) * 100.0 / (@span.max - @span.min)).clamp(0, 100)
        (lower? ? 100 - share : share).round(1)
      end
  end

  # The color of the third of the track that holds the value
  def mark_classes = MARKS[[(position * 3 / 100).floor, 2].min]

  private

  def lower? = @better == :lower
end
