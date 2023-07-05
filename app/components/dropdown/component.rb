class Dropdown::Component < ViewComponent::Base
  def initialize(items:, selected:, button_class: 'bg-gray-200 hover:bg-white')
    super
    @items = items
    @selected = selected
    @button_class = button_class
  end

  attr_reader :items, :selected, :button_class

  def selected_item
    @selected_item ||= items.find { |item| item[:field] == selected }
  end
end
