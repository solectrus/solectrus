class Dropdown::Component < ViewComponent::Base
  renders_many :items, MenuItem::Component
  renders_one :button

  def initialize(
    items:,
    selected: nil,
    button_class: 'bg-gray-200 hover:bg-white'
  )
    super
    @items = items
    @selected = selected
    @button_class = button_class
  end

  attr_reader :items, :selected, :button_class

  def selected_item
    @selected_item ||=
      items.find { |item| item.respond_to?(:field) && item.field == selected }
  end

  def icons?
    items.any?(&:icon)
  end
end
