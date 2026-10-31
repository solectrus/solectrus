# A bar of the parts of a whole in the box of a column of the car page (see
# Car::OverviewBox::Component), like the sources of the charged energy. A
# single part fills it, like the savings against a combustion car.
# Each part has its share of the width and its label inside it. A label has
# its forms from long to short, and each part shows the longest form that
# fits (see component_controller.ts). Without parts, the bar is an empty
# track, like while the figures load.
class Car::ShareBar::Component < ViewComponent::Base
  # A part of the bar. `value` sets its share of the width, `color` its
  # background as a CSS color, like "var(--color-car-pv)", with white text.
  # Without a color, `css` gives the background, the color and the size of
  # the text, like a tint. `labels` are the forms of its label from long to
  # short. A part with a value of 0 would be a gap, so it is left out.
  Segment = Data.define(:value, :color, :css, :labels) do
    def initialize(color: nil, css: nil, labels: [], **) = super
  end
  public_constant :Segment

  # `label` names the parts for a screen reader, as plain text. `pulse` lets
  # the empty track pulse, while the figures load.
  def initialize(segments:, label: nil, pulse: false)
    super()
    @segments = segments
    @label = label
    @pulse = pulse
  end

  attr_reader :segments, :label, :pulse

  def segment_classes(segment)
    class_names(
      'flex min-w-0 items-center justify-center overflow-hidden whitespace-nowrap font-semibold tabular-nums',
      segment.css || 'px-1.5 text-sm text-white',
    )
  end

  # The width of a part comes from its value alone, not from its label
  def segment_style(segment)
    ["flex: #{segment.value.to_f.round(4)} 1 0%", ("background: #{segment.color}" if segment.color)].compact.join('; ')
  end
end
