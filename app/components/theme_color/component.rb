# Renders the theme-color meta tag the browser paints its toolbar with.
class ThemeColor::Component < ViewComponent::Base
  def initialize(chosen: nil)
    super()

    @chosen = chosen
  end

  # A visitor who follows the operating system leaves the server without an
  # answer, because only the browser knows that setting. Both colors go out
  # instead, and the browser picks one by itself. The dark tag comes first:
  # the browser takes the first tag whose media matches, and the tag without
  # media always matches.
  def auto?
    ThemeConfig.x.auto?(@chosen)
  end

  def color
    ThemeConfig.x.color(@chosen)
  end
end
