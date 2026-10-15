# A grouped list of the pages one level down: the rows lie on a card with round corners, each with an icon, the
# name and a chevron. Each row opens its page, whose Ui::TitleBar::Component
# leads back here. Items are hashes with :name, :href and :icon.
class Ui::NavList::Component < ViewComponent::Base
  def initialize(items:, label:)
    super()
    @items = items
    @label = label
  end

  attr_reader :items, :label
end
