# A grouped list: cells on a card with round corners, with an optional
# header above the card and a footer below it. Each cell is a
# Ui::GroupedList::Cell::Component: a link, a button, or a row that holds
# a control at the right, like a segmented control.
class Ui::GroupedList::Component < ViewComponent::Base
  renders_many :cells, Ui::GroupedList::Cell::Component

  def initialize(header: nil, footer: nil)
    super()
    @header = header
    @footer = footer
  end

  attr_reader :header, :footer

  def render?
    cells?
  end
end
