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
    super()
    @name = name
    @items = items
    @top_item = top_item
    @bottom_item = bottom_item
    @selected = selected
    @button_class = button_class
  end

  attr_reader :name, :items, :top_item, :bottom_item, :selected, :button_class

  def grouped?
    items.is_a?(Array) && items.first.is_a?(Hash) && items.first.key?(:name)
  end

  def flat_items
    @flat_items ||=
      if grouped?
        items
          .flat_map { |group| group[:subgroups] || [group] }
          .flat_map { |subgroup| subgroup[:items] }
      else
        items
      end
  end

  def selected_item
    @selected_item ||=
      flat_items.find do |item|
        item.respond_to?(:sensor) && item.sensor == selected
      end
  end

  def icons?
    flat_items.any?(&:icon)
  end

  def menu_class
    return grid_classes if grouped?

    case flat_items.length
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
    return if grouped?

    case flat_items.length
    when ..10
      nil
    when 11..14
      'short:flex short:justify-center'
    else
      'flex justify-center'
    end
  end

  def grid_classes
    @grid_classes ||=
      if grouped?
        column_count = total_columns
        case column_count
        when 1..2
          'grid-cols-1 sm:grid-cols-2'
        when 3
          'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3'
        else
          'grid-cols-1 sm:grid-cols-2 lg:grid-cols-4'
        end
      else
        'grid-cols-1'
      end
  end

  def total_columns
    items.sum { |group| group[:subgroups]&.length || 1 }
  end

  def flat_items_for_group(group)
    group[:subgroups]&.flat_map { |subgroup| subgroup[:items] } || group[:items]
  end

  def render_option(item)
    content_tag(
      :option,
      item.name,
      value: item.href,
      data: item.data,
      selected: (item == selected_item),
    )
  end

  def group_header_class(group)
    if subgroups?(group)
      'relative px-3 pt-3 pb-2 text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-2'
    else
      'px-3 pt-3 pb-2 text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider border-b border-gray-200 dark:border-gray-600 mb-2'
    end
  end

  def spanning_border_class
    'absolute inset-x-0 bottom-0 h-px bg-gray-200 dark:bg-gray-600 w-[calc(200%+1rem)]'
  end

  def subgroups?(group)
    group[:subgroups]&.any?
  end
end
