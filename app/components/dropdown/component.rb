class Dropdown::Component < ViewComponent::Base
  renders_many :items, MenuItem::Component
  renders_one :button

  def initialize(
    name:,
    items:,
    selected: nil,
    button_class: 'bg-gray-200 hover:bg-white dark:text-gray-800.dark:bg-gray-400.dark:hover:bg-gray-300 dark:text-gray-800 dark:bg-gray-400 dark:hover:bg-gray-300'
  )
    super
    @name = name
    @items = items
    @selected = selected
    @button_class = button_class
  end

  attr_reader :name, :items, :selected, :button_class

  def selected_item
    @selected_item ||=
      items.find { |item| item.respond_to?(:sensor) && item.sensor == selected }
  end

  def icons?
    items.any?(&:icon)
  end

  def many?
    items.length > 10
  end
end
