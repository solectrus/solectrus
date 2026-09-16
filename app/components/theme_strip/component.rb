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
#   `opacity: 0` counts as covered. A strip of 8px still counts, one of 4px
#   does not, measured in the iOS 27 simulator with an installed web app.
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

  def style
    [
      'position: fixed',
      'top: 0',
      'left: 0',
      'right: 0',
      # As high as the navigation gets, which is h-16 from the md breakpoint
      # up. Below lg that navigation is gone, and the stylesheet drops the
      # variable to a low band, because the strip is fixed and must stay under
      # the shortest sub navigation. A page that starts its content at the top
      # edge drops it to zero there. An installed app keeps the low band even
      # then, because a strip of no height gives iOS nothing to read, see
      # application.css. The page says which one it is on the body, because
      # this element is permanent and keeps the styles it was rendered with.
      # The fallback holds until the stylesheet arrives, which is when Safari
      # reads the color.
      'height: var(--theme-strip-height, 4rem)',
      # Above the header background, below the navigation (z-40).
      'z-index: 1',
      'pointer-events: none',
      helpers.chrome_background_style,
    ].join('; ')
  end
end
