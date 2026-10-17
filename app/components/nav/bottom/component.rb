# The tab bar of a phone: the first pages of the main navigation, and a tab
# for the page More, which lists the other pages and the secondary items.
class Nav::Bottom::Component < ViewComponent::Base
  MAX_BAR_ITEMS = 4
  # The keyboard focus rings the pill, so it stays clear of the label
  PILL_BASE = 'flex items-center justify-center px-3 py-1 min-h-7 rounded-full group-focus-visible:ring-2 group-focus-visible:ring-white'.freeze
  PILL_ACTIVE = 'bg-white/20'.freeze
  public_constant :MAX_BAR_ITEMS
  private_constant :PILL_BASE, :PILL_ACTIVE

  # `more_current` marks the tab More, for the page More and each page below
  # it. `helios_dot` says that HELIOS needs the user.
  def initialize(items:, more_current:, helios_dot:, unread_count:)
    super()
    @items = items
    @more_current = more_current
    @helios_dot = helios_dot
    @unread_count = unread_count
  end

  attr_reader :unread_count

  def bar_items
    @items.first(MAX_BAR_ITEMS)
  end

  def more_current?
    @more_current
  end

  def helios_dot?
    @helios_dot
  end

  private

  def pill_classes(active:)
    [PILL_BASE, (PILL_ACTIVE if active)]
  end

  def tab_classes(active:)
    [
      'group click-animation flex flex-col items-center justify-center py-2 px-1 gap-1 focus:outline-none',
      active ? 'text-white dark:text-gray-200' : 'text-gray-300 dark:text-gray-400',
    ]
  end
end
