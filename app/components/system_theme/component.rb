# Applies the theme of the operating system, for a visitor who follows it.
#
# Only the browser knows that setting, so the server cannot put the class on the
# html tag. Without this the page paints light and the theme selector corrects
# it once the JavaScript modules have loaded, which is a visible flash on a dark
# system. See https://tailwindcss.com/docs/dark-mode for the pattern.
#
# Tailwind writes the script inline. This one is a file, which the content
# security policy already allows through `script-src 'self'`. Inline would need
# a nonce, and the nonce of this app is the session id, which a guest does not
# have, so the header would carry none and the browser would refuse the script.
#
# It renders for nobody else. A visitor who picked a theme gets the class from
# the server, and `auto?` is false when themes are off or UI_THEME fixes one.
class SystemTheme::Component < ViewComponent::Base
  def initialize(chosen: nil)
    super()

    @chosen = chosen
  end

  def render?
    ThemeConfig.x.auto?(@chosen)
  end

  # No `defer` and no `type=module`, both of which would run the script after
  # the first paint. public/ is served immutable for a year, so the version
  # carries the visitor over to the next release.
  def call
    tag.script(
      src: "/system-theme.js?v=#{Rails.configuration.x.git.commit_version}",
    )
  end
end
