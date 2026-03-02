class MenuItem::Component < ViewComponent::Base
  def initialize( # rubocop:disable Metrics/ParameterLists
    name:,
    href: nil,
    data: {},
    sensor_name: nil,
    id: nil,
    separator_before: false,
    icon: nil,
    icon_only: false,
    text: true,
    current: false,
    badge_count: nil
  )
    super()
    @name = name
    @href = href
    @data = data
    @sensor_name = sensor_name
    @id = id
    @separator_before = separator_before

    @icon = icon
    @icon_only = icon_only
    @text = text
    @current = current
    @badge_count = badge_count
  end

  def target
    href&.start_with?('http') ? '_blank' : nil
  end

  attr_reader :name,
              :href,
              :icon,
              :icon_only,
              :text,
              :current,
              :data,
              :sensor_name,
              :id,
              :separator_before,
              :badge_count

  CSS_CLASSES = %w[block w-full].freeze
  private_constant :CSS_CLASSES

  def call(with_icon: false, css_extra: nil)
    if name == '-'
      separator =
        tag.hr(
          class: 'my-2 hidden lg:block border-gray-200 dark:border-gray-700',
        )

      return separator
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
            title: (icon_only ? name : nil),
            data: data.merge(icon_only ? { controller: 'tooltip' } : {}),
            'aria-current' => current ? 'page' : nil do
      render_inner(with_icon:)
    end
  end

  def render_button(with_icon:, css_extra:)
    tag.button class: [CSS_CLASSES, css_extra],
               title: (icon_only ? name : nil),
               data: data.merge(icon_only ? { controller: 'tooltip' } : {}) do
      render_inner(with_icon:)
    end
  end

  def render_inner(with_icon:)
    tag.span class: 'flex items-center gap-3' do
      safe_join(
        [
          (render_icon if with_icon),
          (render_text(with_icon:) if text),
          (render_badge if badge_count&.positive?),
        ].compact,
      )
    end
  end

  def render_icon
    if icon
      tag.i(class: "fa fa-fw fa-#{icon} fa-xl")
    else
      tag.span(class: 'w-6 block')
    end
  end

  def render_text(with_icon:)
    tag.span(
      name,
      class: [
        'flex-1 text-left uppercase lg:normal-case',
        ('font-medium' if with_icon),
        ('lg:hidden' if icon_only),
      ],
    )
  end

  def render_badge
    tag.span(
      badge_count,
      class:
        'bg-red-500 dark:bg-red-700 text-white dark:text-gray-300 ' \
          'text-xs font-bold rounded-full min-w-5 h-5 flex items-center justify-center px-1.5',
    )
  end
end
