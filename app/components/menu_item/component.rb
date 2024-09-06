class MenuItem::Component < ViewComponent::Base
  def initialize(
    name:,
    href: nil,
    data: {},
    sensor: nil,
    icon: nil,
    current: false,
    content: nil
  )
    super
    @name = name
    @href = href
    @data = data
    @sensor = sensor

    @icon = icon
    @current = current
    @content = content
  end

  def target
    href&.start_with?('http') ? '_blank' : nil
  end

  attr_reader :name, :href, :icon, :current, :content, :data, :sensor

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
      render_link(with_icon:, css_extra:, data:)
    elsif content
      render_content(with_icon:, css_extra:)
    else
      render_button(with_icon:, css_extra:, data:)
    end
  end

  def render_link(with_icon:, css_extra:, data: nil)
    link_to href,
            target:,
            class: [CSS_CLASSES, css_extra],
            data:,
            'aria-current' => current ? 'page' : nil do
      render_inner(with_icon:)
    end
  end

  def render_button(with_icon:, css_extra:, data: nil)
    tag.button(class: [CSS_CLASSES, css_extra], data:) do
      render_inner(with_icon:)
    end
  end

  def render_content(with_icon:, css_extra:)
    tag.div(
      data: {
        'controller' => 'toggle',
        'toggle-max-height-class-value' => 'max-h-28',
      },
    ) do
      render_button(
        with_icon:,
        css_extra: [css_extra],
        data: {
          'toggle-target' => 'button',
          'action' => 'click->toggle#toggle:prevent:stop',
        },
      ) +
        tag.div(
          content,
          data: {
            'toggle-target' => 'dropdown',
          },
          class:
            'max-h-0 transition-max-height ease-out duration-200 overflow-hidden px-6',
        )
    end
  end

  def render_inner(with_icon:)
    tag.span class: 'flex items-center gap-3' do
      if with_icon
        concat(
          if icon
            tag.i(class: "w-6 text-gray-500 fa fa-fw fa-#{@icon} fa-lg")
          else
            tag.span(class: 'w-6 block')
          end,
        )
      end

      concat(tag.span(class: 'flex-1 text-left') { name })
    end
  end
end
