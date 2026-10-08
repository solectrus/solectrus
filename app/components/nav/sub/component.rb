class Nav::Sub::Component < ViewComponent::Base
  renders_many :items, 'ItemComponent'

  def initialize(abbreviate: true)
    super()
    @abbreviate = abbreviate
  end

  attr_reader :abbreviate

  def before_render
    return unless @abbreviate

    items.each_with_index do |item, index|
      item.abbreviate = index.positive? && index < items.size - 1
    end
  end

  # One tab. It leads to its timeframe, and a timeframe that can be shown in
  # more than one way carries that choice as a menu. The menu opens from the
  # current tab alone, because the others lead somewhere first.
  class ItemComponent < ViewComponent::Base
    include NavTabLook

    def initialize(name:, href:, current: false, menu: nil)
      super()
      @name = name
      @href = href
      @current = current
      @menu = menu
      @abbreviate = false
    end

    attr_reader :href, :menu

    def call
      return render(menu_component) if menu.present? && current

      link_to label,
              href,
              class: css_classes,
              'aria-current': (current ? 'location' : nil)
    end

    private

    def menu_component
      Nav::Sub::Menu::Component.new(name:, items: menu, abbreviate: @abbreviate)
    end
  end
end
