# Gives Safari the color for its toolbar.
#
# Safari 26 and later ignore the theme-color meta tag. They read the color from
# the page instead: from a fixed element at the top edge of the viewport, and
# otherwise from the background of the body, which they lighten. So this strip
# sits at that edge, in the color of the app frame, and Safari takes it as it
# is.
#
# The strip is invisible even though nothing hides it: the top navigation lies
# over it and carries no background of its own, so the strip is what shows
# through there. That is why the navigation must stay transparent, see
# nav/top/component.html.slim.
#
# Five things are load-bearing, all measured in Safari 27, none documented by
# Apple:
#
# - Inline styles, not classes. Safari reads the page before the stylesheet
#   arrives, and a strip styled by a class has no size or color at that moment.
#   This is what made the toolbar color differ from one reload to the next.
# - Visible and tall enough. Safari skips a strip that something covers, and
#   `opacity: 0` counts as covered, and it ignores a strip of a few pixels.
# - Ending where the navigation ends, because the content begins there. A
#   taller strip covers the top of the page, and lifting the whole content over
#   it with a z-index breaks the fullscreen chart.
# - Everything that reaches the top edge itself lies over the strip and stays
#   transparent there, so the strip still shows through: the desktop navigation
#   with z-40, the sub navigation and the banner with z-10. Without a desktop
#   navigation the sub navigation starts at that edge, so on a phone the strip
#   would cover it.
# - data-turbo-permanent. Safari holds on to this element, not to the color.
#   When Turbo replaces the body and the element goes with it, the toolbar
#   falls back to the body on the first click after loading.
class ThemeStrip::Component < ViewComponent::Base
  # Below lg the strip has to give way on a page that has no room above its
  # content, see the comment on `height`.
  def initialize(collapse_on_phone: false)
    super()

    @collapse_on_phone = collapse_on_phone
  end

  def call
    tag.div id: 'theme-strip',
            style:,
            aria: {
              hidden: true,
            },
            data: {
              turbo_permanent: true,
            }
  end

  private

  # As high as the navigation gets, which is h-16 from the md breakpoint up.
  #
  # Below lg that navigation is gone, and the page can begin its content right
  # at the top edge, where the strip would cover it. The stylesheet drops the
  # variable to zero at those widths. The fallback holds until the stylesheet
  # arrives, which is when Safari reads the color.
  def height
    if @collapse_on_phone
      'height: var(--theme-strip-height, 4rem)'
    else
      'height: 4rem'
    end
  end

  def style
    [
      'position: fixed',
      'top: 0',
      'left: 0',
      'right: 0',
      height,
      # Above the header background, below the navigation (z-40).
      'z-index: 1',
      'pointer-events: none',
      helpers.chrome_background_style,
    ].join('; ')
  end
end
