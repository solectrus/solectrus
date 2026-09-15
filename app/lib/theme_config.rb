class ThemeConfig
  # Allow global access to the sensor configuration via Rails.application.config
  def self.setup(env)
    Rails.application.config.theme = ThemeConfig.new(env)
  end

  def self.x
    Rails.application.config.theme
  end

  class Error < RuntimeError
  end

  def initialize(env)
    @theme = env['UI_THEME']
    return if @theme.in?(['light', 'dark', nil])

    raise Error, 'UI_THEME must be one of "light" or "dark"'
  end

  # The color of the app frame, for everything the browser reads before any
  # stylesheet applies: the theme-color meta tag and the web manifest. The
  # stylesheet carries the same two values as --color-chrome, and a spec fails
  # if the two drift apart. Change them in both places, or in neither.
  LIGHT_COLOR = '#4f46e5'.freeze # indigo-600
  DARK_COLOR = '#312e81'.freeze # indigo-900
  public_constant :LIGHT_COLOR
  public_constant :DARK_COLOR

  CHOICES = %w[light dark].freeze
  private_constant :CHOICES

  # Every method below takes the theme the visitor picked, as it arrives from
  # the cookie. Passing it lets the server render the right theme with the
  # first byte. Without it the page would start light and the browser would
  # correct itself, which makes the toolbar color flicker on every load.

  # The theme the page renders in, or nil while the browser decides. False when
  # themes are off, which the html tag needs to leave the class out. The two
  # methods below read that answer, so the rules live here alone.
  def html_class(chosen = nil)
    return false unless ApplicationPolicy.themes?

    theme_for(chosen)
  end

  def color(chosen = nil)
    html_class(chosen) == 'dark' ? DARK_COLOR : LIGHT_COLOR
  end

  # True when the visitor follows the operating system. Only the browser knows
  # that setting, so the server cannot name a single theme and the layout
  # offers both colors through a prefers-color-scheme media query instead.
  def auto?(chosen = nil)
    html_class(chosen).nil?
  end

  # UI_THEME fixes the theme for everyone and hides the selector.
  def static?
    return false unless ApplicationPolicy.themes?

    @theme.present?
  end

  private

  def theme_for(chosen)
    return @theme if @theme.present?

    chosen.to_s.presence_in(CHOICES)
  end
end
