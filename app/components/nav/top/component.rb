class Nav::Top::Component < ViewComponent::Base
  renders_many :primary_items, MenuItem::Component
  renders_many :secondary_items, MenuItem::Component
  renders_one :sub_nav

  def initialize(unread_count:, compact: false)
    super()
    @compact = compact
    @unread_count = unread_count
  end

  attr_reader :compact, :unread_count

  def root_item
    primary_items.first
  end

  def primary_items_without_root
    primary_items.drop(1)
  end

  def current_item
    primary_items.find(&:current) || secondary_items.find(&:current)
  end

  def helios_dot?
    secondary_items.any?(&:dot)
  end

  # Nested component for rendering navigation items
  class ItemsComponent < ViewComponent::Base
    def initialize(items:)
      super()
      @items = items
    end

    def call
      safe_join(
        @items.map do |item|
          item.call(with_icon: true, css_extra: css_classes_for_item(item))
        end,
      )
    end

    private

    def css_classes_for_item(item)
      [
        'rounded-md py-2 px-3 click-animation',
        (
          if item.current
            'bg-indigo-800 dark:bg-indigo-950 focus:outline-none focus:ring-2 focus:ring-gray-300 dark:focus:ring-gray-400 focus:ring-offset-0'
          else
            'lg:hover:text-gray-200 lg:hover:bg-indigo-500 dark:lg:hover:bg-indigo-950/50 dark:lg:hover:text-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-300 dark:focus:ring-gray-400 focus:ring-offset-0'
          end
        ),
      ]
    end
  end
end
