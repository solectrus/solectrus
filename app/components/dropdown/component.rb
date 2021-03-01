class Dropdown::Component < ViewComponent::Base
  def initialize(items:, selected:)
    super
    @items = items
    @selected = selected
  end

  def selected_text
    @items.find { |item| item.second == @selected }.first
  end
end
