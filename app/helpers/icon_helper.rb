module IconHelper
  # Renders a Font Awesome icon as inline SVG.
  #
  #   = icon 'gear'
  #   = icon 'gear', class: 'text-xl'
  #   = icon 'circle-check', class: ['fa-lg', color_class]
  #
  # The markup matches what the Font Awesome runtime wrote in the browser until
  # now, down to the `svg-inline--fa` class, so every rule in its stylesheet
  # still applies. That stylesheet is still imported by application.css, which
  # is where `fa-lg`, `fa-fw` and the rest come from.
  #
  # A helper and not a component: a page carries up to 60 icons, and a component
  # instance for each of them costs more than the markup it produces. It is mixed
  # into ViewComponent::Base as well (see config/initializers/view_component.rb),
  # which is why a component calls it without `helpers` - a component that
  # renders outside the Rails render pipeline has no `helpers` at all.
  def icon(name, **options)
    icon = IconSet.find(name)

    tag.svg(
      class:
        class_names('svg-inline--fa', "fa-#{icon.name}", options.delete(:class)),
      'data-prefix': icon.prefix,
      'data-icon': icon.name,
      role: 'img',
      viewBox: "0 0 #{icon.width} #{icon.height}",
      'aria-hidden': 'true',
      **options,
    ) { tag.path(fill: 'currentColor', d: icon.path) }
  end
end
