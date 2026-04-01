class Nav::Bottom::Component < ViewComponent::Base
  renders_many :extra_menu_items, MenuItem::Component
  renders_many :secondary_menu_items, MenuItem::Component

  MAX_BAR_ITEMS = 4
  PILL_BASE = 'flex items-center justify-center px-3 py-1 min-h-7'.freeze
  PILL_ACTIVE = 'bg-white/20 rounded-full group-has-aria-expanded:bg-transparent'.freeze
  private_constant :MAX_BAR_ITEMS, :PILL_BASE, :PILL_ACTIVE

  def initialize(items:, secondary_items:)
    super()
    @items = items
    @secondary_items = secondary_items
  end

  def before_render
    @items.drop(MAX_BAR_ITEMS).each { |item| with_extra_menu_item(**item) }
    @secondary_items.each { |item| with_secondary_menu_item(**item) }
  end

  def bar_items
    @items.first(MAX_BAR_ITEMS)
  end

  private

  def pill_classes(active:)
    [PILL_BASE, (PILL_ACTIVE if active)]
  end
end
