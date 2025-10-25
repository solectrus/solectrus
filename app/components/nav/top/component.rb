class Nav::Top::Component < ViewComponent::Base
  renders_many :primary_items, MenuItem::Component
  renders_many :secondary_items, MenuItem::Component
  renders_one :sub_nav

  def root_item
    primary_items.first
  end

  def primary_items_without_root
    primary_items.drop(1)
  end

  def current_item
    primary_items.find(&:current) || secondary_items.find(&:current)
  end

  # Nested component for rendering navigation items
  class Items < ViewComponent::Base
    def initialize(items:, device:)
      super()
      @items = items
      @device = device
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
      case @device
      when :desktop
        [
          'rounded-md py-2 px-3 click-animation',
          (
            if item.current
              'bg-indigo-800 dark:bg-indigo-950'
            else
              'hover:bg-indigo-500/75 dark:hover:bg-indigo-800'
            end
          ),
        ]
      when :mobile
        ['py-2 px-3', (item.current ? 'rounded-md bg-indigo-700' : '')]
      end
    end
  end
end
