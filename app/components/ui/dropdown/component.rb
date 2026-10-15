class Ui::Dropdown::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  CENTERED = 'left-1/2 -translate-x-1/2 origin-top'.freeze
  private_constant :CENTERED

  renders_many :items, Ui::MenuItem::Component
  renders_one :top_item, Ui::MenuItem::Component
  renders_one :bottom_item, Ui::MenuItem::Component

  renders_one :button

  # The button on the colored bar of the page header
  HEADER_BUTTON_CLASS = 'bg-white/10 text-white hover:bg-white/20 dark:bg-white/5 dark:text-gray-300 dark:hover:bg-white/10'.freeze

  # The button of a phone above a list on the gray page of a grouped list,
  # like the filter of the charging sessions: white, like the cards below it.
  # From lg up, where the page is white, it takes the look of the default.
  PILL_SHAPE = 'max-w-full rounded-lg px-3'.freeze
  PILL_BUTTON_CLASS =
    'bg-white text-slate-700 dark:bg-slate-800 dark:text-slate-300 ' \
    'lg:bg-gray-200 lg:hover:bg-white lg:text-current lg:dark:bg-gray-400 lg:dark:hover:bg-gray-300 lg:dark:text-gray-800'.freeze
  public_constant :HEADER_BUTTON_CLASS, :PILL_SHAPE, :PILL_BUTTON_CLASS

  # The options of that button, for a component that passes them on
  def self.pill_options
    { mobile_shape: PILL_SHAPE, button_class: PILL_BUTTON_CLASS }
  end

  def initialize( # rubocop:disable Metrics/ParameterLists
    name:,
    items:,
    top_item: nil,
    bottom_item: nil,
    selected: nil,
    display_name: nil,
    menu_position: :right,
    disabled: false,
    mobile: true,
    mobile_shape: 'rounded px-2',
    choices: false,
    stacked: false,
    label: nil,
    button_class: 'bg-gray-200 hover:bg-white dark:bg-gray-400 dark:hover:bg-gray-300 dark:text-gray-800'
  )
    super()
    @name = name
    @items = items
    @top_item = top_item
    @bottom_item = bottom_item
    @selected = selected
    @display_name = display_name
    @menu_position = menu_position.to_sym
    @disabled = disabled
    @mobile = mobile
    @mobile_shape = mobile_shape
    @choices = choices
    @stacked = stacked
    @label = label
    @button_class = button_class
  end

  # `mobile_shape` is the corners and the padding of the native select of a
  # phone, `label` names that select for a screen reader.
  #
  # `choices: true` holds several choices at once, one group of items for
  # each, like the order and the calculation of a list. Each group marks its
  # own current item with a check. A native select selects one option only,
  # so such a dropdown shows its menu on a phone too, in the look of a menu
  # of iOS. Its button takes `mobile_shape` there, and `label` names it,
  # because its `display_name` can be an icon.
  #
  # The menu puts the groups side by side in columns. `stacked: true` puts
  # them one below the other, for a few short groups like these choices.
  attr_reader :name,
              :items,
              :top_item,
              :bottom_item,
              :selected,
              :display_name,
              :menu_position,
              :disabled,
              :mobile,
              :mobile_shape,
              :choices,
              :stacked,
              :label,
              :button_class

  # Where the menu hangs from its button. `center` puts it under the button and
  # tucks it to the right edge where the row grows wide enough to hold it
  # beside what it belongs to. `center_always` keeps it under the button at
  # every width, for a button that stands in the middle of a wide area: a menu
  # pinned right would open away from it and run past the edge of the card.
  def menu_position_classes
    case menu_position
    when :center then "#{CENTERED} lg:landscape:left-auto lg:landscape:right-0 lg:landscape:translate-x-0 lg:landscape:origin-top-right"
    when :center_always then CENTERED
    when :right then 'right-0 origin-top-right'
    else
      raise ArgumentError, "Unknown menu_position: #{menu_position.inspect}"
    end
  end

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
      flat_items.find { |item| item.respond_to?(:id) && item.id.to_s == selected.to_s }
  end

  # The button prefers the short name of the selected item, because it stands
  # in the page header with little space
  def button_text
    display_name || selected_item&.short_name || selected_item&.name
  end

  def icons?
    flat_items.any?(&:icon_name)
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
          'grid-cols-[repeat(1,max-content)] sm:grid-cols-[repeat(2,max-content)]'
        when 3..4
          'grid-cols-[repeat(1,max-content)] sm:grid-cols-[repeat(2,max-content)] lg:grid-cols-[repeat(4,max-content)]'
        else
          'grid-cols-[repeat(1,max-content)] sm:grid-cols-[repeat(2,max-content)] lg:grid-cols-[repeat(3,max-content)] xl:grid-cols-[repeat(6,max-content)]'
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

  def chevron_icon(css_class)
    tag.svg(class: css_class, viewbox: '0 0 20 20', fill: 'currentColor', 'aria-hidden': 'true') do
      tag.path(
        'fill-rule': 'evenodd',
        'clip-rule': 'evenodd',
        d:
          'M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z',
      )
    end
  end

  # A native select shows its option as the button, so the option prefers
  # the short name like the button (see button_text)
  def render_option(item)
    content_tag(:option, item.short_name || item.name, value: item.href, data: item.data, selected: (item == selected_item))
  end

  # A phone has the native select, unless the dropdown holds choices
  def native_select?
    mobile && !choices
  end

  def button_shape
    if choices
      "#{mobile_shape} h-9 text-base lg:h-auto lg:rounded-md lg:px-4 lg:py-2 lg:text-sm"
    else
      'rounded-md px-2 sm:px-4 py-2 text-sm'
    end
  end

  # The menu of choices is translucent and blurs the page below it, like a
  # menu of iOS. Its items therefore have no background of their own.
  def menu_surface_class
    if choices
      'rounded-2xl shadow-xl bg-white/80 backdrop-blur-xl dark:bg-slate-800/80'
    else
      'rounded-md shadow-lg bg-white dark:bg-gray-800'
    end
  end

  def menu_item_classes(item)
    classes = [
      if choices
        'py-2 px-3 hover:bg-black/5 dark:hover:bg-white/10'
      else
        'py-2 px-3 hover:bg-gray-100 dark:hover:bg-gray-700 dark:bg-gray-800'
      end,
    ]
    classes << 'font-bold' if item.current && !choices

    # In a stacked menu, the names of the groups divide the items
    if item.respond_to?(:separator_before) && item.separator_before && !stacked
      classes << 'border-t border-gray-200 dark:border-gray-600'
    end

    classes
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
