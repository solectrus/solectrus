# The tooltip of a figure of the overview (see Car::PeriodOverview::Component),
# like the charged energy or the charging cost, and of a bar of the timeline
# of a day (see Car::TimelineBar::Component). A bar has a title, and below it
# its `lines`: first its time, then like the address of an offsite session.
# The parts of its value are rows with the swatch of their color, and at
# times their share. A part without a color, like the cost of the guest, is
# a detail below them. The `bar` of a span (see Car::SpanBar::Component)
# stands below the details, like below the rate it places. Its rows, like
# the lowest and the highest rate, lead to a page, so they show in a sheet
# alone: a hover tooltip closes before the pointer reaches them.
# The notes stand at the end, smaller than the rows. Without parts, the notes
# are the whole tooltip.
class Car::Tooltip::Component < ViewComponent::Base
  # A part of a value with the color of its part of a bar, a CSS color like
  # "var(--color-car-pv)", and its whole share in percent
  Part = Data.define(:label, :value, :color, :percent) do
    def initialize(color: nil, percent: nil, **) = super
  end
  public_constant :Part

  # `parts` are Parts. `icon` stands above the title, like the source of a
  # charge.
  def initialize(title: nil, icon: nil, lines: [], parts: [], notes: [], bar: nil)
    super()
    @title = title
    @icon = icon
    @lines = lines
    @parts = parts
    @notes = notes
    @bar = bar
  end

  attr_reader :title, :icon, :lines, :parts, :notes, :bar

  def colored = parts.select(&:color)

  def details = parts.reject(&:color)
end
