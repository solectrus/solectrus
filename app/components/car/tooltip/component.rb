# The tooltip of a figure of the overview (see Car::PeriodOverview::Component),
# like the charged energy or the charging cost, and of a bar of the timeline
# of a day (see Car::TimelineBar::Component). A bar has a title, and below it
# its `lines`: first its time, then like the address of an offsite session.
# The parts of its value are rows with the swatch of their color, and at
# times their share. A part without a color, like the cost of the guest, is
# a detail below them. Details of one `group` stand together, like the cost
# and the cost per 100 km. The notes stand at the end, smaller than the
# rows. Without parts, the notes are the whole tooltip.
class Car::Tooltip::Component < ViewComponent::Base
  # A part of a value with the color of its part of a bar, a CSS color like
  # "var(--color-car-pv)", and its whole share in percent. Successive details
  # of one `group` share a box.
  Part = Data.define(:label, :value, :color, :percent, :group) do
    def initialize(color: nil, percent: nil, group: nil, **) = super
  end
  public_constant :Part

  # `parts` are Parts. `icon` stands above the title, like the source of a
  # charge.
  def initialize(title: nil, icon: nil, lines: [], parts: [], notes: [])
    super()
    @title = title
    @icon = icon
    @lines = lines
    @parts = parts
    @notes = notes
  end

  attr_reader :title, :icon, :lines, :parts, :notes

  def colored = parts.select(&:color)

  # The details in their groups, each group in its own box
  def detail_groups = parts.reject(&:color).chunk_while { |part, other| part.group == other.group }
end
