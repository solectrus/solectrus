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
  # `path` takes further attributes of the path, like a stroke.
  def icon(name, path: {}, **options)
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
    ) { tag.path(fill: 'currentColor', d: icon.path, **path) }
  end

  # The outline of a car in the units of the view box of the icon (512). Half
  # of it lies outside the shape, so it is about 0.7px wide at 18px.
  CAR_OUTLINE = 40
  private_constant :CAR_OUTLINE

  # A car in the color of a car, wherever a car is named. The car stands on
  # light and on dark backgrounds, so a sharp outline draws it in the
  # opposite brightness: a dark car gets a white outline, a light car a gray
  # one. The outline lies under the fill (paint-order), so the shape keeps
  # its size.
  def car_icon(color, **options)
    outline = dark_color?(color) ? '#ffffff' : '#64748b'

    icon(
      'car',
      class: class_names('shrink-0', options.delete(:class)),
      style: "color: #{color}",
      path: { stroke: outline, 'stroke-width': CAR_OUTLINE, 'stroke-linejoin': 'round', 'paint-order': 'stroke' },
      **options,
    )
  end

  # Whether a color like "#585656" is darker than a middle gray, by its
  # relative luminance (WCAG). The gray #767676 has 0.18.
  def dark_color?(color)
    hex = color.to_s[/\A#(\h{6})\z/, 1]
    return false unless hex

    r, g, b =
      hex.scan(/../).map do
        value = it.to_i(16) / 255.0
        value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
      end
    (r * 0.2126) + (g * 0.7152) + (b * 0.0722) < 0.18
  end

  # The width of the gap that the slash cuts into the icon, in the units of
  # the view box
  SLASH_GAP = 64
  private_constant :SLASH_GAP

  # Renders an icon crossed out by a slash, like the slash icons of Font
  # Awesome (eye-slash), which the free set has for a few icons only.
  #
  #   = slashed_icon 'plug', class: 'text-8xl'
  #
  # The icon sits in the middle of the wider box of the slash. A mask cuts a
  # gap along the slash, so the slash stands apart from the icon. The mask
  # sits on a group, not on the shifted path, because a mask takes the
  # coordinates of the element that uses it.
  def slashed_icon(name, **options)
    icon = IconSet.find(name)
    slash = IconSet.find('slash')
    mask_id = "#{icon.name}-slash-mask"

    tag.svg(
      class:
        class_names('svg-inline--fa', "fa-#{icon.name}", options.delete(:class)),
      role: 'img',
      viewBox: "0 0 #{slash.width} #{slash.height}",
      'aria-hidden': 'true',
      **options,
    ) do
      safe_join(
        [
          slash_mask(slash, mask_id),
          tag.g(mask: "url(##{mask_id})") do
            tag.path(
              fill: 'currentColor',
              d: icon.path,
              transform: "translate(#{(slash.width - icon.width) / 2} 0)",
            )
          end,
          tag.path(fill: 'currentColor', d: slash.path),
        ],
      )
    end
  end

  private

  # White keeps the icon, black cuts it: the slash with a wide stroke
  def slash_mask(slash, mask_id)
    tag.mask(id: mask_id, maskUnits: 'userSpaceOnUse') do
      safe_join(
        [
          tag.rect(
            x: -slash.width,
            y: -slash.height,
            width: slash.width * 3,
            height: slash.height * 3,
            fill: 'white',
          ),
          tag.path(
            d: slash.path,
            fill: 'black',
            stroke: 'black',
            'stroke-width': SLASH_GAP,
          ),
        ],
      )
    end
  end
end
