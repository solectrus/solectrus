class Dropdown::Component < ViewComponent::Base
  def initialize(items:, selected:)
    super
    @items = items
    @selected = selected
  end

  def selected_item
    @selected_item ||= @items.find { |item| item[:field] == @selected }
  end
end
