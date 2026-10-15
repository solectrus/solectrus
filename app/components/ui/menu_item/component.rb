class Ui::MenuItem::Component < ViewComponent::Base
  def initialize( # rubocop:disable Metrics/ParameterLists
    name: nil,
    short_name: nil,
    href: nil,
    data: {},
    key: nil,
    id: nil,
    separator_before: false,
    icon: nil,
    icon_only: false,
    text: true,
    current: false,
    badge_count: nil,
    badge_data: nil,
    dot: false,
    leading: nil,
    component: nil
  )
    super()
    @name = name
    @short_name = short_name
    @href = href
    @data = data
    @key = key
    @id = id
    @separator_before = separator_before

    @icon_name = icon
    @icon_only = icon_only
    @text = text
    @current = current
    @badge_count = badge_count
    @badge_data = badge_data
    @dot = dot
    @leading = leading
    @component = component
  end

  def target
    href&.start_with?('http') ? '_blank' : nil
  end

  attr_reader :name,
              :short_name,
              :href,
              :icon_name,
              :icon_only,
              :text,
              :current,
              :data,
              :key,
              :id,
              :separator_before,
              :badge_count,
              :badge_data,
              :dot,
              :leading,
              :component

  CSS_CLASSES = %w[block w-full].freeze
  private_constant :CSS_CLASSES

  # `with_check: true` puts a check before a current item and the same space
  # before any other, so the names stand in one column
  def call(with_icon: false, with_check: false, css_extra: nil)
    if name == '-'
      separator =
        tag.hr(
          class: 'my-2 hidden lg:block border-gray-200 dark:border-gray-700',
        )

      return separator
    end

    if href
      render_link(with_icon:, with_check:, css_extra:)
    else
      render_button(with_icon:, with_check:, css_extra:)
    end
  end

  def render_link(with_icon:, with_check:, css_extra:)
    link_to href,
            target:,
            class: [CSS_CLASSES, css_extra],
            title: (icon_only ? name : nil),
            data: data.merge(icon_only ? { controller: 'tooltip' } : {}),
            'aria-current' => current ? 'page' : nil do
      render_inner(with_icon:, with_check:)
    end
  end

  def render_button(with_icon:, with_check:, css_extra:)
    tag.button class: [CSS_CLASSES, css_extra],
               title: (icon_only ? name : nil),
               data: data.merge(icon_only ? { controller: 'tooltip' } : {}) do
      render_inner(with_icon:, with_check:)
    end
  end

  def render_inner(with_icon:, with_check:)
    tag.span class: 'flex items-center gap-3' do
      safe_join(
        [
          (render_check if with_check),
          (render_icon if with_icon),
          leading,
          (render_text(with_icon:, with_check:) if text),
          (render_badge if badge_count&.positive?),
          (render_dot if dot),
        ].compact,
      )
    end
  end

  def render_check
    tag.span(class: 'flex w-4 shrink-0 justify-center') do
      icon('check', class: 'text-sm') if current
    end
  end

  def render_icon
    if icon_name
      icon(icon_name, class: 'fa-fw fa-xl')
    else
      tag.span(class: 'w-6 block')
    end
  end

  # A phone writes the name of a link of the navigation in capitals, but not
  # a choice, which has a check
  def render_text(with_icon:, with_check:)
    tag.span(
      name,
      class: [
        'flex-1 text-left',
        ('uppercase lg:normal-case' unless with_check),
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
      data: badge_data,
    )
  end

  def render_dot
    tag.span(
      class: 'block size-2.5 rounded-full bg-amber-400 dark:bg-amber-500',
      'aria-hidden': true,
    )
  end
end
