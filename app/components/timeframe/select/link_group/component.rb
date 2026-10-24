# A group of links below the fields of the timeframe select of a phone, like
# the comparisons of the years, which a wide screen has in the menu of its
# tab. Each item is a hash with :name, :href and :current.
class Timeframe::Select::LinkGroup::Component < ViewComponent::Base
  def initialize(heading:, items:)
    super()
    @heading = heading
    @items = items
  end

  attr_reader :heading, :items

  def link_classes(item)
    select = Timeframe::Select::Component
    [
      'min-w-0',
      Timeframe::Select::RelativePicker::Component::COMPACT_CLASSES,
      item[:current] ? select::SELECTED_COLORS : select::UNSELECTED_COLORS,
    ]
  end
end
