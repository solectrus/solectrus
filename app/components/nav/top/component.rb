class Nav::Top::Component < ViewComponent::Base
  renders_many :items, 'ItemComponent'
  renders_one :sub_nav

  def current_item
    items.find(&:current?)
  end

  class ItemComponent < ViewComponent::Base
    def initialize(
      name:,
      href: nil,
      target: nil,
      data: nil,
      icon: nil,
      alignment: nil
    )
      super
      @name = name
      @href = href
      @target = target
      @data = data || {}
      @icon = icon
      @alignment = alignment || :left
    end

    def before_render
      @is_current = @href && href_current?
    end

    def href_current?
      current_page?(@href) ||
        # TODO: Move this out of the component!
        (@href == root_path && controller_name == 'home') ||
        (@href.include?('top10') && controller_name == 'top10') ||
        (@href.include?('settings') && controller_name == 'prices')
    end

    attr_reader :name, :target

    def current?
      @is_current
    end

    def left?
      @alignment == :left
    end

    def right?
      @alignment == :right
    end

    def css_classes
      base = %w[text-white rounded-md py-2 px-3 uppercase tracking-wider block]

      if current?
        base + %w[bg-indigo-700]
      else
        base + %w[hover:bg-indigo-500 hover:bg-opacity-75]
      end
    end

    def call(icon: @icon)
      @href ? render_link(icon:) : render_button(icon:)
    end

    def render_link(icon:)
      link_to @href,
              target:,
              class: css_classes,
              title: icon ? name : nil,
              data:
                @data.merge(
                  controller: icon ? 'tippy' : nil,
                  action: 'toggle#hide',
                ),
              'aria-current' => current? ? 'page' : nil do
        icon ? tag.i(class: "fa fa-#{@icon} fa-lg") : name
      end
    end

    def render_button(icon:)
      tag.button class: css_classes,
                 title: icon ? name : nil,
                 data:
                   @data.merge(
                     controller: icon ? 'tippy' : nil,
                     action: "toggle#hide #{@data[:action]}",
                   ) do
        icon ? tag.i(class: "fa fa-#{@icon} fa-lg") : name
      end
    end
  end
end
