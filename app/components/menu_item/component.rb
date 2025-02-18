class MenuItem::Component < ViewComponent::Base
  def initialize( # rubocop:disable Metrics/ParameterLists
    name:,
    href: nil,
    data: {},
    sensor: nil,
    icon: nil,
    text: true,
    current: false
  )
    super
    @name = name
    @href = href
    @data = data
    @sensor = sensor

    @icon = icon
    @text = text
    @current = current
  end

  def target
    href&.start_with?('http') ? '_blank' : nil
  end

  attr_reader :name, :href, :icon, :text, :current, :data, :sensor

  CSS_CLASSES = %w[block w-full].freeze
  private_constant :CSS_CLASSES

  def call(with_icon: false, css_extra: nil)
    if name == '-'
      return(
        tag.hr(
          class: 'my-2 hidden lg:block border-gray-200 dark:border-gray-700',
        )
      )
    end

    if href
      render_link(with_icon:, css_extra:)
    else
      render_button(with_icon:, css_extra:)
    end
  end

  def render_link(with_icon:, css_extra:)
    link_to href,
            target:,
            class: [CSS_CLASSES, css_extra],
            data:,
            'aria-current' => current ? 'page' : nil do
      render_inner(with_icon:)
    end
  end

  def render_button(with_icon:, css_extra:)
    tag.button class: [CSS_CLASSES, css_extra], data: @data do
      render_inner(with_icon:)
    end
  end

  def render_inner(with_icon:)
    tag.span class: 'flex items-center gap-3' do
      if with_icon
        concat(
          if icon
            tag.i(class: "fa fa-fw fa-#{@icon} fa-xl")
          else
            tag.span(class: 'w-6 block')
          end,
        )
      end

      if text
        concat(
          tag.span(class: ['flex-1 text-left', ('font-medium' if with_icon)]) do
            name
          end,
        )
      end
    end
  end
end
