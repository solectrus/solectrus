# A list of pages one level down, in the style of the iOS settings: an icon, the
# name and a chevron in each row. Each row opens its page, whose
# Ui::TitleBar::Component leads back here. Items are hashes with :name, :href
# and :icon.
class Ui::NavList::Component < ViewComponent::Base
  def initialize(items:, label:)
    super()
    @items = items
    @label = label
  end

  attr_reader :items, :label
end
