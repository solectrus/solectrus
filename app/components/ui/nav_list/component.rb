# A grouped list of the pages one level down (see Ui::GroupedList::Component),
# each row with an icon, the name and a chevron. Each row opens its page,
# whose Ui::TitleBar::Component leads back here. Items are hashes with :name,
# :href and :icon. An optional footer explains the pages below the card.
class Ui::NavList::Component < ViewComponent::Base
  def initialize(items:, label:, footer: nil)
    super()
    @items = items
    @label = label
    @footer = footer
  end

  attr_reader :items, :label, :footer
end
