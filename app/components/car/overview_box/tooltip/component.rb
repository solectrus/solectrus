# The tooltip of a figure of the overview (see Car::OverviewBox::Component),
# like the charged energy or the charging cost, and of a bar of the timeline
# of a day (see Car::TimelineBar::Component). A bar has a title, and below it
# its `lines`: first its time, then like the address of an offsite session.
# The parts of its value are rows with the swatch of their color, and at
# times their share. A part without a color, like the cost of the guest, is
# a detail below them. The `bar` of a span (see Car::SpanBar::Component)
# stands below the details, like below the rate it places.
# The notes stand at the end, smaller than the rows. Without parts, the notes
# are the whole tooltip.
class Car::OverviewBox::Tooltip::Component < ViewComponent::Base
  # `parts` are Car::OverviewBox::Component::Part
  def initialize(title: nil, lines: [], parts: [], notes: [], bar: nil)
    super()
    @title = title
    @lines = lines
    @parts = parts
    @notes = notes
    @bar = bar
  end

  attr_reader :title, :lines, :parts, :notes, :bar

  def colored = parts.select(&:color)

  def details = parts.reject(&:color)
end
