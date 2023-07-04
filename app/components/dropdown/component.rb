class Dropdown::Component < ViewComponent::Base
  def initialize(items:, selected:, on_dark: false, small: false)
    super
    @items = items
    @selected = selected
    @on_dark = on_dark
    @small = small
  end

  attr_reader :items, :selected, :on_dark, :small

  def selected_item
    @selected_item ||= items.find { |item| item[:field] == selected }
  end

  def font_size_class
    small ? 'text-sm' : 'text-base'
  end

  def button_class
    if on_dark
      ['text-gray-300 hover:bg-indigo-500 hover:bg-opacity-75', font_size_class]
    else
      ['text-gray-700 hover:bg-gray-50', font_size_class]
    end
  end

  def select_class
    [
      on_dark ? 'bg-transparent text-gray-300' : 'text-gray-700',
      font_size_class,
    ]
  end
end
