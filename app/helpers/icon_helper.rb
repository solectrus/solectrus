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

  # The relative luminance (WCAG) above which a color is light, with less
  # than 1.6:1 against a white page, and below which it is dark, about a
  # middle gray or darker, like the indigo bar of the page header
  LIGHT = 0.6
  DARK = 0.2
  private_constant :LIGHT, :DARK

  # A car in the color of a car, wherever a car is named. A light color
  # would disappear on a white page, a dark one on a dark page or on the
  # page header, so it gets a sharp outline in the opposite brightness: gray
  # around a light car, white around a dark one. A color between stands out
  # everywhere and gets none. The outline depends on the color alone, so a
  # car looks the same everywhere. It lies under the fill (paint-order), so
  # the shape keeps its size. In dark mode a light color is dimmed (see the
  # utility car-color).
  def car_icon(color, **options)
    outline = car_outline(color)

    icon(
      'car',
      class: class_names('shrink-0 car-color', options.delete(:class)),
      style: "--car-color: #{color}",
      path:
        if outline
          { stroke: outline, 'stroke-width': CAR_OUTLINE, 'stroke-linejoin': 'round', 'paint-order': 'stroke' }
        else
          {}
        end,
      **options,
    )
  end

  # The color of the outline of a car, or nil for none
  def car_outline(color)
    luminance = relative_luminance(color)
    return unless luminance

    if luminance > LIGHT
      '#64748b' # slate-500
    elsif luminance < DARK
      '#ffffff'
    end
  end

  # The relative luminance (WCAG) of a color like "#585656", from 0 for
  # black to 1 for white
  def relative_luminance(color)
    hex = color.to_s[/\A#(\h{6})\z/, 1]
    return unless hex

    r, g, b =
      hex.scan(/../).map do
        value = it.to_i(16) / 255.0
        value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
      end
    (r * 0.2126) + (g * 0.7152) + (b * 0.0722)
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
