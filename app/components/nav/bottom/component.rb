class Nav::Bottom::Component < ViewComponent::Base
  PILL_BASE = 'flex items-center justify-center px-3 py-1 min-h-7'.freeze
  PILL_ACTIVE = 'bg-white/20 rounded-full group-has-aria-expanded:bg-transparent'.freeze
  private_constant :PILL_BASE, :PILL_ACTIVE

  def initialize(items:)
    super()
    @items = items
  end

  attr_reader :items

  private

  def pill_classes(active:)
    [PILL_BASE, (PILL_ACTIVE if active)]
  end
end
