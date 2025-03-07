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

  def menu_class
    case items.length
    when ..10
      # Few items (up to 10): Always display in one column
      'grid grid-cols-1'
    when 11..14
      # Medium amount of items (11 - 14):
      # Use one column on tall screens, two columns on shorter screens
      'grid grid-cols-1 short:grid-cols-2'
    else
      # Many items (> 14): Always display in two columns
      'grid grid-cols-2'
    end
  end
end
