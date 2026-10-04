# The place of a list without rows: a large icon and a text. The content of
# the block comes between them, for example the name of the empty list.
class EmptyList::Component < ViewComponent::Base
  def initialize(icon:, text:)
    super()
    @icon_name = icon
    @text = text
  end

  attr_reader :icon_name, :text
end
