# The tooltip of a box of the overview (see Car::OverviewBox::Component), like
# the head with the ring or the tile of the charging cost. The parts of its
# value are rows with the swatch of their color, and at times their share. A
# part without a color, like the cost of the guest, is a detail below them.
# The notes stand at the end, smaller than the rows. Without parts, the notes
# are the whole tooltip.
class Car::OverviewBox::Tooltip::Component < ViewComponent::Base
  # `parts` are Car::OverviewBox::Component::Part
  def initialize(parts: [], notes: [])
    super()
    @parts = parts
    @notes = notes
  end

  attr_reader :parts, :notes

  def colored = parts.select(&:color)

  def details = parts.reject(&:color)
end
