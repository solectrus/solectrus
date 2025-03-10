class Dropdown::Component < ViewComponent::Base
  renders_many :items, MenuItem::Component
  renders_one :top_item, MenuItem::Component
  renders_one :bottom_item, MenuItem::Component

  renders_one :button

  def initialize(
    name:,
    items:,
    top_item: nil,
    bottom_item: nil,
    selected: nil,
    button_class: 'bg-gray-200 hover:bg-white dark:text-gray-800.dark:bg-gray-400.dark:hover:bg-gray-300 dark:text-gray-800 dark:bg-gray-400 dark:hover:bg-gray-300'
  )
    super
    @name = name
    @items = items
    @top_item = top_item
    @bottom_item = bottom_item
    @selected = selected
    @button_class = button_class
  end

  attr_reader :name, :items, :top_item, :bottom_item, :selected, :button_class

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
      'columns-1'
    when 11..14
      # Medium amount of items (11 - 14):
      # Use one column on tall screens, two columns on shorter screens
      'columns-1 short:columns-2'
    else
      # Many items (> 14): Always display in two columns
      'columns-2'
    end
  end

  def extra_item_class
    case items.length
    when ..10
      nil
    when 11..14
      'short:flex short:justify-center'
    else
      'flex justify-center'
    end
  end
end
